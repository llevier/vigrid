#!/bin/sh
#################################################################################################################################
#
# This material is part of VIGRID extensions to GNS3 for Trainings & CyberRange designs
#
# (c) Laurent LEVIER for script, designs and technical actions, https://github.com/llevier/
# LICENCE: Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA)
#
# Each dependancies (c) to their respective owners
#
#################################################################################################################################

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# To have script execution traced...
SCRIPT_NAME=`basename $0`
LOG_FILE="/tmp/$SCRIPT_NAME-log.out"

PROG_ARG=$1

VIGRID_CONF="/home/gns3/etc/vigrid.conf"

#
# Functions
#

# Error display & management
Error()
{
  TXT=$*
  
  until false
  do
    echo
    echo -n "$TXT do you wish to (F)orce continue, (C)ontinue/(R)un a sub shell/(E)xit script [F/C/R/E) ? "
    read ANS
    
    case "$ANS" in
      f|F)
        return 2
        ;;
      c|C)
        return 1
        ;;
      r|R)
        echo "Launching /bin/sh via script command. Output will be added to the log file"
        echo "Once you finished, end with the 'exit' command."
        echo
        # script /bin/sh /tmp/shell-$$.log
        /bin/sh -xi
        
        # echo "Concatening shell output to log file..."
        # cat /tmp/shell-$$.log >>$LOG_FILE
        # rm /tmp/shell-$$.log
        TXT="Shell ended,"
        ;;
      e|E)
        echo "Ok. bye bye then..."
        exit 1
        ;;
    esac
  done
}

Display()
{
  NO_CR=0
  NO_HEAD=0
  
  until false
  do
    case "$1" in
      "-n")
        NO_CR=1
        shift
        ;;
      "-h")
        NO_HEAD=1
        shift
        ;;
      *)
        TXT=$*
        break
        ;;
    esac
  done

  [ $NO_HEAD -eq 0 ] && echo && echo "############# VIGRID DISPLAY ################################################################"

  [ $NO_HEAD -eq 0 ] && echo -n "# "
  
  [ $NO_CR -eq 0 ] && echo "$TXT" && echo
  [ $NO_CR -eq 1 ] && echo -n "$TXT"
  
  return 0
}

#
# Script starts
#

rm -f $LOG_FILE 2>/dev/null
(
# Part of script to run on Master
if [ "x$PROG_ARG" = "x" ]
then
  Display ""
  Display -h -n "
Vigrid update script: Add Vigrid-API on all slaves.

This script requires to be launched via the vigrid-run command to all/targetted slaves, so Vigrid configuration must be accurate.

Upon any issue, script will pause, proposing to (force) continue, run a sub shell or exit procedure.
Everything will be logged to $LOG_FILE.

Upon any question with default answer, validate the choice.
IMPORTANT: if this server is using DHCP, I'll set the IP address to the one obtained. This IP might change in the future,
especially if you selected CyberRange designs.

#############################################################################################

Press [RETURN] to start..."

  read ANS

  Display -n -h "
First, do you wish to change [BACKSPACE], sometimes there are some issues with terminals... [y/N] ? "
  read ANS

  if [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
  then
    Display -h -n "Ok, now just press [BACKSPACE] then [RETURN] "
    read ANS
    stty erase $ANS 2>/dev/null
    Display -h "[BACKSPACE] set now."
  fi

  SCRIPT_CWD=`/usr/bin/pwd`
  [ "x$SCRIPT_CWD" = "x" ] && Display "I cant find where I am, exiting" && exit 1

  # Sanity checks
  Display "Ok, let's start..."

  Display "Adding entries on Vigrid Master NGinx configuration"
  
  . /home/gns3/etc/vigrid.conf
  if [ $? -ne 0 ]
  then
    Error 'Cant load /home/gns3/etc/vigrid.conf, am I on a Vigrid Master server ? Exiting.'
    exit 1
  fi

  if [ $VIGRID_TYPE -ne 3 ]
  then
    echo "I am sorry but this is not a Master Vigrid server, exiting"
    exit 1
  fi
  
  # Adding Vigrid-NAS to NGinx
  if [ "x$VIGRID_NAS_SERVER" != "x" ]
  then
    NAME=`echo $VIGRID_NAS_SERVER | awk 'BEGIN { FS=":"; } { print $1; }'`
    HOST=`echo $VIGRID_NAS_SERVER | awk 'BEGIN { FS=":"; } { print $2; }'`
    
    Display -h "    Generating NGinx configuration for Vigrid-NAS ($HOST)"
    
    if [ -f /etc/nginx/sites/CyberRange-443-$NAME.conf ]
    then
      cp /home/gns3/vigrid/confs/nginx/vigrid-www-https-for_nas.conf /etc/nginx/sites/CyberRange-443-$NAME.conf
      if [ $? -ne 0 ]
      then
        echo 'Cant create CyberRange-443-$NAME.conf from vigrid-www-https-for_nas.conf template, exiting'
        exit 1
      fi

      sed -ie "s/%%NAS_HOST%%/$NAME/" /etc/nginx/sites/CyberRange-443-$NAME.conf
      sed -ie "s/%%NAS_IP%%/$HOST/" /etc/nginx/sites/CyberRange-443-$NAME.conf
    fi
  fi  
  
  for i in $VIGRID_GNS_SLAVE_HOSTS
  do
    NAME=`echo $i | awk 'BEGIN { FS=":"; } { print $1; }'`
    HOST=`echo $i | awk 'BEGIN { FS=":"; } { print $2; }'`
    PORT=`echo $i | awk 'BEGIN { FS=":"; } { print $3; }'`

    Display -h "    Generating NGinx configuration for $HOST"
    cp /home/gns3/vigrid/confs/nginx/vigrid-www-https-for_slave.conf /etc/nginx/sites/CyberRange-443-$NAME.conf
    if [ $? -ne 0 ]
    then
      Error 'Cant create CyberRange-443-$NAME.conf from vigrid-www-https-for_slave.conf template, exiting'
      exit 1
    fi

    sed -ie "s/%%SLAVE_HOST%%/$NAME/" /etc/nginx/sites/CyberRange-443-$NAME.conf
    sed -ie "s/%%SLAVE_IP%%/$HOST/" /etc/nginx/sites/CyberRange-443-$NAME.conf
    sed -ie "s/%%SLAVE_PORT%%/$PORT/" /etc/nginx/sites/CyberRange-443-$NAME.conf
  done
  
  Display -h "    Restarting OpenResty on Master"
  service openresty stop
  service openresty start

  Display "Spreading Vigrid config to slaves..."
  /home/gns3/vigrid/bin/vigrid-spread -K /home/gns3/etc/id_GNS3 -U root -S /home/gns3/etc/vigrid.conf || Error 'Vigrid-spread error,'

  Display "Updating Vigrid on slaves..."
  /home/gns3/vigrid/bin/vigrid-run -S -K /home/gns3/etc/id_GNS3 -U root -A '/home/gns3/bin/vigrid-update'
  
  Display "Adding API on slaves..."
  /home/gns3/vigrid/bin/vigrid-run -S -K /home/gns3/etc/id_GNS3 -U root -A '/home/gns3/vigrid/install/vigrid2-add-api-to-slave.sh SLAVE'

  exit
fi

############## Part of script to run on Slave(s) or NAS

VIGRID_ROOT="/home/gns3/vigrid"
# [ "x$PROG_ARG" = "xNAS" ] && VIGRID_ROOT="/Vstorage/GNS3/vigrid"

HOST=`hostname`
Display "Adding API to Slave $HOST..."

Display "Installing PHP FPM..." && apt install -y php-fpm || Error 'Install failed,'
apt install -y php-curl php-mail php-net-smtp || Error 'Install failed,'
Display "Removing Apache2 forced install..." && apt purge -y apache2* || Error 'Uninstall failed,'

Display -h "  Configuring PHP pools..."

PHP_VER=`php -v|head -1|awk '{print $2;}'| awk 'BEGIN { FS="."; } { print $1"."$2; }'`
Display -h "    PHP version is $PHP_VER."

Display -h "    Removing default PHP pools..."
rm /etc/php/$PHP_VER/fpm/pool.d/* || Error 'Cant remove pool,'

Display -h "    Adding Vigrid standard pool..."
cp $VIGRID_ROOT/confs/php/php-pfm-pool.d-vigrid-www.conf /etc/php/$PHP_VER/fpm/pool.d/vigrid-www.conf
sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/php/$PHP_VER/fpm/pool.d/vigrid-www.conf

Display -h "Enabling & starting PHP-FPM..."
systemctl enable php$PHP_VER-fpm
service php$PHP_VER-fpm stop
service php$PHP_VER-fpm start

# NGinx for Vigrid extensions
Display -h "Installing OpenResty server..."
Display -h "  Installing required packages..." && apt install -y curl bc gnupg2 ca-certificates lsb-release || Error 'Install failed,'

Display -h -n "Adding OpenResty for Vigrid-load API..."
Display -h "  Adding OpenResty key..."
curl https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg
[ $? -ne 0 ] && Error 'Add failed,'

Display -h "  Updating apt sources for OpenResty..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list > /dev/null
 [ $? -ne 0 ] && Error 'Update failed,'

Display -h "  Updating system..." && apt update -y  || Error 'Update failed,'
Display -h "  Installing OpenResty..." && apt install -y openresty || Error 'Install failed,'

Display -h "  Configuring OpenResty..."
rm -rf /etc/nginx 2>/dev/null
ln -s /usr/local/openresty/nginx/conf /etc/nginx
mkdir -p /var/log/nginx /etc/nginx/sites /etc/nginx/ssl

cp /$VIGRID_ROOT/confs/nginx/nginx.conf /etc/nginx/nginx.conf
if [ $? -ne 0 ]
then
  Error 'Cant copy nginx.conf, exiting'
  exit 1
fi

cp $VIGRID_ROOT/confs/nginx/vigrid-CyberRange-443-api.conf /etc/nginx/sites/CyberRange-443-api.conf
if [ $? -ne 0 ]
then
  Error 'Cant create CyberRange-443-api.conf from template, exiting'
  exit 1
fi

sed -ie "s/%%PHP_VER%%/$PHP_VER/" /etc/nginx/sites/CyberRange-443-api.conf

Display -h "Adding www-data user to gns3 group..."
usermod -a www-data -G gns3 >/dev/null 2>/dev/null || Error 'add failed,'

Display -h "Generating SSL certificate for localhost..."
mkdir -p /etc/nginx/ssl >/dev/null 2>/dev/null
( printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth") | openssl req -x509 -out /etc/nginx/ssl/localhost.crt -keyout /etc/nginx/ssl/localhost.key -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' || Error 'Certificate generation failed,'

Display -h "Enabling & starting NGinx..."
systemctl enable openresty
service openresty stop
service openresty start

################################

# Adding Vigrid monitoring
Display "Installing & enabling Vigrid-load monitoring..."
cp $VIGRID_ROOT/etc/init.d/vigrid-load /etc/init.d/
systemctl enable --now vigrid-load

Display -h ""

) 2>&1 | tee -a $LOG_FILE
