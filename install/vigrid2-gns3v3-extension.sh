#!/bin/bash
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

echo "Script to add GNS3 v3 on host"
echo

echo "### Checking server..."
if [ -x /home/gns3/vigrid/install/vigrid2-gns3v3-extension.sh -o -f /home/gns3/vigrid/confs/nginx/vigrid-www-https-master-v3.conf ]
then
  GNS_ROOT="/home/gns3"
  echo "    It seems some Vigrid files, I will consider I am on a Vigrid server and add a OpenResty instance for GNS3v3 as well"
  until false
  do
    HOSTNAME_OLD=`hostname`
    echo -n "Please provide me a altername hostname than '$HOSTNAME_OLD' for GNS3v3: "
    read HOSTNAME_NEW
    
    [ "x$HOSTNAME_OLD" != "x$HOSTNAME_NEW" ] && break
  done
  
  echo "You are on a host already having GNS3 present. You must be aware GNS3v3 will update Projects versions to 10."
  echo "Once done, updated projects will no longer be visible for GNS3 v2 (until 2.2.49 at least)."
  echo "To solve this, best method is to duplicate your /home/gns3/GNS3/projects (v2) to an alternate project path."
  echo "Please notice I will not do that replication, but I need the target directory to exist now."
  
  until false
  do
    echo -n "Please provide me the existing projects directory GNS3 *v3* will use: "
    read GNS3v3_PROJECTS
    
    [ -d "$GNS3v3_PROJECTS" ] && break
    echo "I am sorry, I cant find that directory"
  done
else
  GNS_ROOT="/tmp"
  echo "    Ok, it does not seem to be a Vigrid server. Will just ensure there already GNS3v2 installed..."
  GNS=`dpkg --list|grep gns3-server`
  [ "x$GNS" = "x" ] && echo "I am sorry, but I can only be launched from a server with GNS3v2 already setup" && exit 1
fi

# echo "### Updating OS..."
# apt update -y && apt full-upgrade -y && apt autoclean -y && apt autoremove -y

GNS_VERSION=`curl https://github.com/GNS3/gns3-server/releases 2>/dev/null | grep "\/tree\/" | sed 's/^\s*<a href=\"//i' | sed 's/\"\s*.*$//' | awk -F '/' '{print $NF;}' | grep "^v3"|head -1`

if [ "x$GNS_VERSION" = "x" ]
then
  echo "I am sorry, I cant find which is latest GNS3 v3 version on https://github.com/GNS3/gns3-server/tags"
  echo -n "Can you please go to that URL and tell me which it is:"
  read GNS_VERSION
else
  echo
  echo "I detect latest GNS3v3 version from github is $GNS_VERSION"
fi

CHK=`which jq`
if [ "x$CHK" = "x" ]
then
  Display "Installing jq"
  apt install -y jq 
  [ $? -ne 0 ] && echo 'Install failed,exiting' && exit 1
fi

GNS_VERSION=""
if [ -x /usr/local/bin/gns3server ]
then
  GNS_VERSION=`/usr/local/bin/gns3server -v`
  CHK=`echo $GNS_VERSION|grep "^3\."`
  if [ "x$CHK" != "x" ]
  then
    echo "I also detect a GNS3 version $GNS_VERSION already present on this host."
    echo
    until false
    do
      echo -n "Do you want to replace it ? [y/N] "
      read ANS
      [ "x$ANS" = "xy" -o "x$ANS" = "xY" ] && GNS_VERSION="" && break
      [ "x$ANS" = "xn" -o "x$ANS" = "xN" -o "x$ANS" = "x" ] && break
    done
  fi
fi

if [ "x$GNS_VERSION" = "x" ]
then
  echo "### Building GNS3v3..."

  GNS_URL="https://github.com/GNS3/gns3-server/archive/refs/tags/$GNS_VERSION.tar.gz"

  echo
  echo "### Downloading GNS3$GNS_VERSION to $GNS_ROOT..."

  rm $GNS_ROOT/gns3$GNS_VERSION.tar.gz 2>/dev/null
  wget -qO $GNS_ROOT/gns3$GNS_VERSION.tar.gz "$GNS_URL"

  [ ! -f "$GNS_ROOT/gns3$GNS_VERSION.tar.gz" ] && echo "I cant find $GNS_ROOT/gns3$GNS_VERSION.tar.gz, exiting" && exit 1

  echo "### Extracting gns3$GNS_VERSION.tar.gz to $GNS_ROOT/gns3$GNS_VERSION..."
  rm -rf $GNS_ROOT/gns3$GNS_VERSION 2>/dev/null
  mkdir -p $GNS_ROOT/gns3$GNS_VERSION 2>/dev/null
  tar -C $GNS_ROOT/gns3$GNS_VERSION -xzf $GNS_ROOT/gns3$GNS_VERSION.tar.gz 

  GNS_RELEASE=`echo $GNS_VERSION| sed 's/^v//'`
  echo "    RELEASE=$GNS_RELEASE"
  cd $GNS_ROOT/gns3$GNS_VERSION/gns3-server-$GNS_RELEASE
  [ $? -ne 0 ] && echo "I cant cd to $GNS_ROOT/gns3$GNS_VERSION/gns3-server-$GNS_RELEASE, exiting" && exit 1

  if [ -f /usr/lib/python3.12/EXTERNALLY-MANAGED ]
  then
    echo "### Resetting Python from 'externally-managed-environment'" 
    rm -f /usr/lib/python3.12/EXTERNALLY-MANAGED 2>/dev/null
  fi

  echo "### Running GNS3 Dockerfile..."
  while IFS= read LINE
  do
    if [ "x$LINE" != "x" ]
    then
      CMD=`echo $LINE|awk '{print $1;}'`
      ARGS=`echo $LINE|awk '{$1="";print $0;}'`
      
      case "$CMD" in 
        "ENV")
          echo "### Setting ENV to $ARGS..."
          set $ARGS
          ;;
        "RUN")
          echo "### Running: $ARGS..."
          eval "$ARGS"
          [ $? -ne 0 ] && echo "Error running "$ARGS", exiting" && exit 1
          ;;
      esac

    fi
  done <Dockerfile
fi

[ ! -f /usr/local/bin/gns3server ] && echo "I cant find /usr/local/bin/gns3server, migration failed to me. Exiting" && exit 1

echo "### GNS3v3 adding seems to have been done properly.
- GNS3v2 remains /usr/sbin/gns3server.
- GNS3$GNS_VERSION is /usr/local/bin/gns3server."

### Vigrid instance
if [ "x$HOSTNAME_NEW" != "x" ]
then
  cp /home/gns3/vigrid/confs/nginx/vigrid-www-https-master-v3.conf /etc/nginx/sites/CyberRange-443-$HOSTNAME_NEW.conf
  if [ $? -ne 0 ]
  then
    echo 'Cant create CyberRange-443-$HOSTNAME_NEW.conf from template, exiting'
    exit 1
  fi

  PHP_VER=`php -v|head -1|awk '{print $2;}'| awk 'BEGIN { FS="."; } { print $1"."$2; }'`
  echo "    PHP version is $PHP_VER."
  sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/nginx/sites/CyberRange-443-$HOSTNAME_NEW.conf
  sed -i "s/%%HOSTNAME%%/$HOSTNAME_NEW/" /etc/nginx/sites/CyberRange-443-$HOSTNAME_NEW.conf

  echo "### Restarting OpenResty..."
  service openresty restart
  
  echo "### Installing GNS3v3 service..."
  cp /home/gns3/vigrid/lib/systemd/system/gns3v3.service /usr/lib/systemd/system/gns3v3.service
  if [ $? -ne 0 ]
  then
    echo 'Cant create GNS3v3 service from template, exiting'
    exit 1
  fi
  echo "### Enabling GNS3v3 service..."
  systemctl enable gns3v3.service

  echo "### Configuring GNS3v3..."
  rm -rf /home/gns3/.config/GNS3/3.0 2>/dev/null
  mkdir -p /home/gns3v3/.config/GNS3/3.0 2>/dev/null
  chown gns3:gns3 /home/gns3v3/.config/GNS3/3.0 2>/dev/null
  cp /home/gns3/.config/GNS3/gns3_server.conf /home/gns3v3/.config/GNS3/3.0/gns3_server.conf
  if [ $? -ne 0 ]
  then
    echo 'Cant create GNS3v3 configuration from GNS3v2 gns3_server.conf, exiting'
    exit 1
  fi

  echo "### Setting GNS3v3 port to 3083 for GNS3v3 so it can work simultaneously with GNS3v2..."
  sed -i 's/3080/3083/' /home/gns3v3/.config/GNS3/3.0/gns3_server.conf

  echo "    Adjusting GNS3v3 configuration..."
  sed -i 's/^path.*$/path = \/usr\/local\/bin\/gns3server/' /home/gns3v3/.config/GNS3/3.0/gns3_server.conf
  sed -i 's/^user/compute_username/' /home/gns3v3/.config/GNS3/3.0/gns3_server.conf
  sed -i 's/^password/compute_password/' /home/gns3v3/.config/GNS3/3.0/gns3_server.conf
  sed -i "s;^projects_path.*$;projects_path = $GNS3v3_PROJECTS;" /home/gns3v3/.config/GNS3/3.0/gns3_server.conf

  echo "; Secrets directory" >>/home/gns3v3/.config/GNS3/3.0/gns3_server.conf
  echo "secrets_dir = /home/gns3v3/.config/GNS3/3.0/secrets" >>/home/gns3v3/.config/GNS3/3.0/gns3_server.conf

  echo "; Path where custom configs are stored" >>/home/gns3v3/.config/GNS3/3.0/gns3_server.conf
  echo "configs_path = /home/gns3v3/GNS3/3.0/configs" >>/home/gns3v3/.config/GNS3/3.0/gns3_server.conf

  echo "### Starting GNS3v3 service..."
  systemctl start gns3v3.service
  GNSv3_UP="OK"
else
  echo "### Setting up GNS3v3 service with GNS3v2 scripts..."
  cp /usr/lib/systemd/system/gns3server.service /usr/lib/systemd/system/gns3v3server.service
  sed -i 's/usr\/bin/usr\/local\/bin/g' /usr/lib/systemd/system/gns3v3server.service
  sed -i 's/GNS3 /GNS3v3 /g' /usr/lib/systemd/system/gns3v3server.service

  until false
  do
    echo -n "### Do you want me to switch running GNS3 service, replacing v2 with v3 ? [Y/n] "
    read YN
    if [ "x$YN" = "xn" -o "x$YN" = "xN" ]
    then
      echo "Ok, job done then."
      exit 0
    elif [ "x$YN" = "xy" -o "x$YN" = "xY" -o "x$YN" = "x" ]
    then
      echo "Fully disabling old GNS3v2 service..."
      systemctl disable --now gns3server
      echo "Fully enabling GNS3v3 service..."
      systemctl enable --now gns3v3server
      GNSv3_UP="OK"
    fi
  done
fi

if [ "x$GNSv3_UP" != "x" ]
then
  if [ "x$HOSTNAME_NEW" != "x" ] # Vigrid
  then
    GNS_PORT="3083"
  else
    GNS_PORT="3080"
  fi
  GNS_VERSION=`curl http://localhost:$GNS_PORT/v3/version 2>/dev/null | jq .version | sed 's/"//g'`
  CHK=`echo $GNS_VERSION|grep "^3"`

  if [ "x$CHK" = "x" ]
  then
    echo "There might be a problem, I cant find GNS3v3 listening on localhost:$GNS_PORT. Please check"
    exit 1
  else
    echo "### Great, I detect GNS3v$GNS_VERSION listening on localhost:$GNS_PORT, GNS3v3 should now be available."
    echo "    PLEASE NOTICE:"
    echo "    - DEFAULT GNS3v3 CREDENTIALS are: user=admin, password=admin"
    
    if [ "x$HOSTNAME_NEW" != "x" ] # Vigrid
    then
      echo "    - Direct Heavy client access is performed thru: http://$HOSTNAME_NEW:443"
      echo "    - Direct WebUI access is performed thru:        http://$HOSTNAME_NEW:443/static/web-ui/controllers"
    fi
    exit 0
  fi
fi
