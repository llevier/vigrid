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

# To have script execution traced...
SCRIPT_NAME=`basename $0`
LOG_FILE="/tmp/$SCRIPT_NAME-log.out"

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
      "-d")
        NO_HEAD=2
        shift
        ;;
      *)
        TXT=$*
        break
        ;;
    esac
  done

  [ $NO_HEAD -eq 0 ] && echo && echo "############# VIGRID DISPLAY ################################################################"

  [ $NO_HEAD -eq 1 ] && echo -n "# "
  
  [ $NO_CR -eq 0 ] && echo "$TXT"
  [ $NO_CR -eq 1 ] && echo -n "$TXT"
  
  return 0
}

#
# Script starts
#
rm -f $LOG_FILE 2>/dev/null
(
Display ""
Display -h -n "
Vigrid extension: Network Deployment tool for servers, Ansible

This script should be launched from a Vigrid Master server.
Its purpose is to install Ansible, completing Vigrid deployer service.
Vigrid-deployer will install baremetal when Ansible will configure them internally.

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

# Sanity checks
Display "Ok, let's start..."
OS_RELEASE=`cat /etc/os-release|grep "^PRETTY_NAME" | awk 'BEGIN { FS="="; } { print $2;}' | sed 's/\"//g'`
OS_CHK=`echo "$OS_RELEASE" | egrep -i "Ubuntu.*(20|22)"|wc -l`
Display -h -n "I see I am launched on a $OS_RELEASE, "
[ $OS_CHK -ge 1 ] && Display -h "perfect to me !"
[ $OS_CHK -ge 1 ] || Display -h "not the one I expected, not sure I will work fine over it."

Display "Checking if we are on a Vigrid Master..."

VIGRID_CONF="/home/gns3/etc/vigrid.conf"
[ -f  $VIGRID_CONF ] || Error "I cant find /home/gns3/etc/vigrid.conf, not a Vigrid Master"
Display "  Loading Vigrid.conf..."
. $VIGRID_CONF
[ "x$VIGRID_NAS_SERVER" = "x" -o "x$VIGRID_SSHKEY_GNS" = "x" -o "x$VIGRID_SSHKEY_NAS" = "x" ] && Error "I am sorry, but I am not on a Vigrid Master or it has no Vigrid-NAS"

# Server update
Display "Lets update your server first"

apt update -y || Error "Command exited with an error,"
apt full-upgrade -y || Error "Command exited with an error,"
apt autoclean -y || Error "Command exited with an error,"
apt autoremove -y || Error "Command exited with an error,"

Display -h ""
Display -h "Updating Vigrid as well..."
/home/gns3/bin/vigrid-update || Error "Updated failed"

Display -h "Adding Ansible repo..."
apt-add-repository -y ppa:ansible/ansible || Error "Command exited with an error,"

Display -h "Installing Ansible..."
apt install ansible || Error "Command exited with an error,"

Display -h "Backing up Ansible hosts file"
mv /etc/ansible/hosts /etc/ansible/hosts.org || Error "Command exited with an error,"

Display -h "Populating /etc/ansible/hosts"
VIGRID_NAS_NAME=`echo $VIGRID_NAS_SERVER| sed 's/"//g' | awk -F ':' '{print $1;}'`
VIGRID_NAS_IP=`echo $VIGRID_NAS_SERVER| sed 's/"//g' | awk -F ':' '{print $2;}'`
echo "#
# Vigrid Ansible hosts file
#
[Vigrid_NAS]
$VIGRID_NAS_NAME ansible_host=$VIGRID_NAS_IP  ansible_ssh_private_key_file=$VIGRID_SSHKEY_NAS ansible_ssh_common_args='$VIGRID_SSHKEY_OPTIONS'

[Vigrid_GNS]
" >/etc/ansible/hosts

Display -h "  Extracting exports from $VIGRID_NAS_NAME ($VIGRID_NAS_IP)"
HOSTS_EXPORTS=`showmount -e "$VIGRID_NAS_IP" | grep "\/NFS\/" | awk '{print $NF;}' | sort -u`
HOSTS_NAS=`ssh -i $VIGRID_SSHKEY_NAS $VIGRID_NAS_IP cat /etc/hosts`

if [ "x$HOSTS_EXPORTS" = "x" ]
then
  Error "I am sorry, I cant find any exports towards Vigrid servers, I will not populate /etc/ansible/hosts."
else
  for HOST in $HOSTS_EXPORTS
  do
    # server01 ansible_host=198.148.118.68 ansible_user=root
    HOST_IP=`echo "$HOSTS_NAS" | egrep "^\b([0-9]{1,3}\.){3}[0-9]{1,3}\b.*\s+$HOST"|awk '{print $1;}'|tail -1`
    if [ "x$HOST_IP" = "x" ]
    then
      echo "$HOST" >>/etc/ansible/hosts
    else
      echo "$HOST ansible_host=$HOST_IP ansible_ssh_private_key_file=$VIGRID_SSHKEY_GNS ansible_ssh_common_args='$VIGRID_SSHKEY_OPTIONS' ansible_user=gns3 ansible_sudo_user=root" >>/etc/ansible/hosts
    fi    
  done
  
  Display -h "Ok, Ansible hosts file is now populated"
fi

Display -h "Feel free to update Ansible hosts file (/etc/ansible/hosts) at your convenience"

Display -h "  Ansible pinging hosts..."
ansible -m ping all
[ $? -ne 0 ] && Display -h "Ansible ping exited with an error" && sleep 5

Display "Ansible is now installed on the Vigrid Master, it can be used to control Vigrid Slaves
You might find into /home/gne3/vigrid/lib/ansible_collections/vigrid useful playbooks

"

) 2>&1 | tee -a $LOG_FILE
