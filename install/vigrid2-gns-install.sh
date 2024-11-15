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
# INSTALLATION TYPES
#
# Vigrid TYPE:
#  1- Standalone GNS3 server    (no NAS, GNS3 default, requires additional disk for storage)
#  2- Standalone GNS3 server     with NAS storage (/Vstorage/NFS/hostname)
#  5- GNS3 Scalable slave server with NAS storage (/Vstorage/NFS/hostname)
#  3- GNS3 Farm MASTER server    with NAS storage (/Vstorage/GNS3/GNS3farm)
#  4- GNS3 Farm slave server     with NAS storage (/Vstorage/GNS3/GNS3farm)
#
#  6- VIGRIDsolo USB server     (no NAS, GNS3 default, native storage)
#
# Vigrid NET:
#  1- No network configuration change, you will manage
#  2- TINY Cyber Range network configuration (requires 4 network interfaces: WAN, Admin, Blue, Red)
#  3- FULL Cyber Range network configuration (requires 6 network interfaces: WAN, SuperAdmin, BlueAdmin, RedAdmin, Blue, Red)
#
#################################################################################################################################

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# To have script execution traced...
SCRIPT_NAME=`basename $0`
LOG_FILE="/tmp/$SCRIPT_NAME-log.out"

PROG_ARG=$1

VIGRID_PASSWD="/home/gns3/etc/vigrid-passwd"
VIGRID_PASSWD_TELEPORT="/home/gns3/etc/VIGRIDteleport-passwd"
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

dec2ip()
{
  local IP=""
  local DEC=$@
  for e in `seq 3 -1 0`
  do
    OCTET=`echo "$DEC / 256^$e"|bc`
    DEC=`echo "$DEC - ($OCTET * 256^$e)"|bc`
    IP="$IP$DELIM$OCTET"
    DELIM=.
  done
  
  T=$IP
}

#
# Script starts
#

rm -f $LOG_FILE 2>/dev/null
(
Display ""
Display -h -n "
Vigrid extension: GNS3 server (standalone, standalone over NAS, slave or scalable over NAS) install script

This script requires to be launched on the latest Ubuntu LTS version, Internet access (for updates & packages) ready.

Upon any issue, script will pause, proposing to (force) continue, run a sub shell or exit procedure.
Everything will be logged to $LOG_FILE.

Upon any question with default answer, validate the choice.
IMPORTANT: if this server is using DHCP, I'll set the IP address to the one obtained. This IP might change in the future,
especially if you select CyberRange designs.

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
OS_RELEASE=`cat /etc/os-release|grep "^PRETTY_NAME" | awk 'BEGIN { FS="="; } { print $2;}' | sed 's/\"//g'`
OS_CHK=`echo "$OS_RELEASE" | egrep -i "Ubuntu\s+24"|wc -l`
Display -n -h "I see I am launched on a $OS_RELEASE, "
[ $OS_CHK -ge 1 ] && Display -h "perfect to me !"
[ $OS_CHK -ge 1 ] || Display -h "not the one I expected, not sure I will work fine over it."

HOST=`/usr/bin/hostname`

if [ -f /proc/cpuinfo ]
then
  KVM=`egrep '^flags.*(vmx|svm)' /proc/cpuinfo 2>/dev/null`
  if [ "x$KVM" = "x" ]
  then
    Display -n "ATTENTION !! KVM extension is not detected in your CPU. It means you will *NOT* be able to emulate any VM on this server
  Knowing this, do you with to continue [y/N] ? "
    read ANS
    
    [ "x$ANS" = "xn" -o "x$ANS" = "xN" -o "x$ANS" = "x" ] && exit 0
  fi
else
  Display "Cant find /proc/cpuinfo, cant check if KVM extensions are present."
fi

# Server update
Display "Lets update your server first"

apt update -y || Error "Command exited with an error,"
apt full-upgrade -y || Error "Command exited with an error,"
apt autoclean -y || Error "Command exited with an error,"
apt autoremove -y || Error "Command exited with an error,"

Display "Removing cloud-init service..."
apt remove -y cloud-init
apt autoremove -y
apt purge -y cloud-init
rm -rf /etc/cloud
find / -name '*cloud-init*'

CHK=`which sipcalc`
if [ "x$CHK" = "x" ]
then
  Display "Installing sipcalc"
  apt install -y sipcalc || Error 'Install failed,'
fi

if [ "x$PROG_ARG" != "xsolo" ]
then
  Display "Now it is time to define a timezone for your server. All GNS3 servers should have the same"
  dpkg-reconfigure tzdata || Error "error, "

  Display "Ok, now the first important Vigrid question."
  until false
  do
    Display -h "Please select one of the Vigrid designs below:

    1- Standalone GNS3 server    (no NAS, GNS3 default, requires additional disk(s) for storage)
    2- Standalone GNS3 server     with NAS storage
    3- GNS3 Farm MASTER server    with NAS storage
    4- GNS3 Farm slave server     with NAS storage
    5- GNS3 Scalable slave server with NAS storage
    6- VIGRIDsolo USB server     (no NAS, GNS3 default, native storage)

  Your choice ? "
    read VIGRID_TYPE
    
    [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 6 ] && break
  done
else
  Display "Autoselected Vigrid type: 6- VIGRIDsolo USB server  (no NAS, GNS3 default, native storage)"
  VIGRID_TYPE=6
fi

Display "Getting host network configuration (static IP+routes or DHCP, DNS & default route), first NIC with IP as a reference"
HOST_NIC=`ip addr show up | grep "^[0-9]" | egrep -v "(virbr0|docker0|lo):"| awk '{print $2;}'| sed 's/://g'`

for i in $HOST_NIC
do
  HOST_NIC_DHCP=`ip addr show $i|grep "inet.*dynamic" |head -1| awk '{print $2;}' | grep -v "::" | tr -s ' '`
  HOST_NIC_IP_FULL=`ip addr show $i|grep "inet" |head -1| awk '{print $2;}' | grep -v "::" | tr -s ' '`
  HOST_NIC_IP=`echo "$HOST_NIC_IP_FULL"| awk 'BEGIN { FS="/"; } {print $1;}'`
  
  [ "x$HOST_NIC_DHCP" != "x" -o "x$HOST_NIC_IP" != "x" ] && break
done

HOST_DHCP=$HOST_NIC_DHCP
HOST_IP_FULL=$HOST_NIC_IP_FULL
HOST_IP=$HOST_NIC_IP

HOST_ROUTE=`ip route |grep default|awk '{print $3;}'`

HOST_DNS=`resolvectl | grep 'Current DNS Server:'| awk '{print $NF;}'|sort -u`
[ "x$HOST_DNS" = "x" ] && HOST_DNS=`dig github.com +short +identify | awk '{print $4;}'`
HOST_DNS=`echo $HOST_DNS`
  
if [ $VIGRID_TYPE -ge 2 -a $VIGRID_TYPE -le 5 ] # Vigrid with NAS
then
  # Vigrid with NAS then
  Display "Installing autofs"
  apt install -y autofs nfs-common || Error "Command exited with an error,"

  until false
  do
    Display -n "Architecture relying on a central Network Area Storage. Please provide the IP address of that NAS: "
    read VIGRID_NAS_SERVER_IP
    
    CHK=`sipcalc $VIGRID_NAS_SERVER_IP|grep "^-\[ERR : "|wc -l`
    [ $CHK -eq 0 ] && break
  done

  until false
  do
    Display -n "Please provide the host name of that NAS: "
    read VIGRID_NAS_SERVER_NAME
    
    [ "x$CHK" != "x" ] && break
  done

  until false
  do
    Display -n "Please indicate NAS Storage mode, either 'ZFS' or 'BTRfs' : "
    read VIGRID_STORAGE_MODE
    
    VIGRID_STORAGE_MODE=`echo $VIGRID_STORAGE_MODE|tr /a-z/ /A-Z/`
    
    [ "x$VIGRID_STORAGE_MODE" = "xZFS" ] && VIGRID_STORAGE_MODE="ZFS" && break
    [ "x$VIGRID_STORAGE_MODE" = "xBTRFS" ] && VIGRID_STORAGE_MODE="BTRfs" && break
  done
  
  Display "Let me ask what $VIGRID_NAS_SERVER_NAME shares over NFS:"
  showmount -e $VIGRID_NAS_SERVER_IP 2>/dev/null
  [ $? -ne 0 ] && Display "Apparently it does not answer..."

  until false
  do
    Display -n "Please indicate NAS shared root directory (starting with /, eg '/Vstorage'): "
    read VIGRID_STORAGE_ROOT
    
    if [ "x$VIGRID_STORAGE_ROOT" != "x" ]
    then
      CHK=`echo $VIGRID_STORAGE_ROOT|grep "^\/"`
      [ "x$CHK" != "x" ] && break
      
      echo "Must be /directory_name"
    fi
  done

  if [ $VIGRID_TYPE -ne 1 -a $VIGRID_TYPE -ne 6 ]
  then
    Display -h "Adding Vigrid-NAS to /etc/hosts"
    echo "$VIGRID_NAS_SERVER_IP $VIGRID_NAS_SERVER_NAME $VIGRID_NAS_SERVER_NAME.GNS3" >>/etc/hosts

    Display "Generating SSH key for NAS control (no password)"
    mkdir -p /home/gns3/etc >/dev/null 2>/dev/null || Error 'cant create /home/gns3/etc...'
    VIGRID_SSHKEY_NAS="/home/gns3/etc/id_NAS"
    ssh-keygen -N "" -f $VIGRID_SSHKEY_NAS || Error 'generation failed,'

    Display "Please provide the NAS root password so Vigrid Master can add its SSH key to control it:"
    cat $VIGRID_SSHKEY_NAS.pub | ssh $VIGRID_NAS_SERVER_IP 'mkdir -p /root/.ssh 2>/dev/null;cat >>/root/.ssh/authorized_keys'

    HOSTNAME=`hostname`
    VIGRID_SSHKEY_OPTIONS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    
    Display "Adding $HOSTNAME ($HOST_IP) host to /etc/hosts..."
    echo "$HOST_IP $HOSTNAME $HOSTNAME.GNS3" | ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP 'cat >>/etc/hosts'
    
    Display "Adding Vigrid shares for server..."
    Display -h "  Creating datasets for server..."
    if [ "x$VIGRID_STORAGE_MODE" = "xZFS" ]
    then
      ZFS_ROOT=`echo $VIGRID_STORAGE_ROOT|sed 's/^\///'`
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "zfs create -p $ZFS_ROOT/NFS/$HOSTNAME/GNS3mount/GNS3/projects"
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "zfs create -p $ZFS_ROOT/NFS/$HOSTNAME/var-lib-docker"
    fi

    if [ "x$VIGRID_STORAGE_MODE" = "xBTRfs" ]
    then
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "btrfs sub create $VIGRID_STORAGE_ROOT/NFS"
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "btrfs sub create $VIGRID_STORAGE_ROOT/NFS/$HOSTNAME"
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "btrfs sub create $VIGRID_STORAGE_ROOT/NFS/$HOSTNAME/GNS3mount"
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "btrfs sub create $VIGRID_STORAGE_ROOT/NFS/$HOSTNAME/GNS3mount/GNS3"
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "btrfs sub create $VIGRID_STORAGE_ROOT/NFS/$HOSTNAME/GNS3mount/GNS3/projects"
      ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP "btrfs sub create $VIGRID_STORAGE_ROOT/NFS/$HOSTNAME/var-lib-docker"
    fi

    Display -h "  Adding Vigrid shares to /etc/exports..."
    echo "
/Vstorage/NFS/$HOSTNAME/GNS3mount                $HOSTNAME.GNS3(rw,async,no_root_squash,no_subtree_check)
/Vstorage/NFS/$HOSTNAME/GNS3mount/GNS3           $HOSTNAME.GNS3(rw,async,no_root_squash,no_subtree_check)
/Vstorage/NFS/$HOSTNAME/GNS3mount/GNS3/projects  $HOSTNAME.GNS3(rw,async,no_root_squash,no_subtree_check)
/Vstorage/NFS/$HOSTNAME/var-lib-docker           $HOSTNAME.GNS3(rw,async,no_root_squash,no_subtree_check)
    " | ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP 'cat >>/etc/exports'
    
    Display -h  "Refreshing exports..."
    ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP 'exportfs -a'
  fi

  Display "NOTA: I will not check mountpoints because Vigrid server network configuration might not be able to reach it."
fi

if [ $VIGRID_TYPE -eq 6 ]
then
  Display  "You select VIGRIDsolo server design, creating storage according to Vigrid's standard."
  mkdir -p /Vstorage/home 2>/dev/null
fi

if [ $VIGRID_TYPE -eq 1 ]
then
  Display  "You select the Standalone GNS3 server design, it requires to configure the storage according to Vigrid's standard."

  Display -n "Ok, let's configure storage. Vigrid enforces storage standards (filesystem and directories).
Are you ok I setup the additional disks for Vigrid's storage [Y/n] ? "
  read ANS

  # Installing ZFS storage
  if [ "x$ANS" = "xy" -o "x$ANS" = "xY" -o "x$ANS" = "x" ]
  then
    # ZFS package install
    Display -h "Now server is updated, let's install ZFS package"
    apt install -y zfsutils-linux || Error "Command exited with an error,"
    [ -x /usr/sbin/zfs ] || Error "Cant find /usr/bin/zfs,"

    # ZFS disk identification
    Display  -n "Identifying available hard drives: "
    DSK=`lsblk -S -o NAME | tail -n +2`
    Display $DSK

    Display -h "  Existing partitions:"
    for i in $DSK
    do
      Display "  - Disk $i:"
      PART=`lsblk -r /dev/$i | tail -n +2`
      IFSBAK=$IFS
      IFS="
"
      for j in $PART
      do
        Display -h "    - $j"
      done
      IFS=$IFSBAK
    done

    # Identify free ones : size >1G, not mounted, not part of a pvdisplay
    until false
    do
      FREE_PARTS=""
      for i in $DSK
      do
        PART=`lsblk -ro NAME /dev/$i | tail -n +2 | awk '{print $NF;}'`
        IFSBAK=$IFS
        IFS="
"
        for j in $PART
        do
          PART_IS_FREE=1
          
          # Partitions end with a digit
          CHK=`echo "$j" | grep "[0-9]$"`
          if [ "x$CHK" != "x" ]
          then
            # Partition must not be mounted
            CHK=`mount | grep "\/dev\/$j "|wc -l`
            [ $CHK -gt 0 ] && PART_IS_FREE=0
            
            # Partition is not part of a pvdisplay
            CHK=`pvdisplay -s | grep "\/dev\/$j\""|wc -l`
            [ $CHK -gt 0 ] && PART_IS_FREE=0

            # Partition must have an acceptable size (G or T)
            CHK=`lsblk -ro SIZE /dev/$j|tail -n +2|egrep "[GT]"|wc -l`
            [ $CHK -eq 0 ] && PART_IS_FREE=0
           
            # Still free ? Ok valid !
            [ $PART_IS_FREE -eq 1 ] && FREE_PARTS="$FREE_PARTS"$j" "
          fi
        done
        IFS=$IFSBAK
      done

      # I detected no free partitions
      FREE_PARTS=""
      if [ "x$FREE_PARTS" = "x" ]
      then
        Display -h "(!!) I detected no free partition but I may have made a mistake, I will ask anyway the partition(s) to build the storage"
      fi

      until false
      do
        Display -h "Please provide a space separated list of FREE partition(s)/full device(s) that will be used for the ZFS storage from: $FREE_PARTS"
        read ZFS_PARTS
        [ "x$ZFS_PARTS" != "x" ] && break
      done

      NUM_PARTS=`echo $ZFS_PARTS | wc -w`
      
      if [ $NUM_PARTS -gt 1 ]
      then
        Display -h "You provided multiple partitions. These must be exactly the same to build an array".
        until false
        do
          Display -h  "Please select ZFS array type:"
          Display -h  "  0:  RAID0 -> data spread on all drives. Upon failure of one, you loose everything"
          Display -h  "  1:  RAID1 -> Mirror: you loose have the total size of drives, you may loose one at a time"
          [ $NUM_PARTS -ge 3 ] && Display -h  "  5:  RAID5 -> Simply parity: you loose 1/3 of total size of drives, you may loose one at a time"
          [ $NUM_PARTS -ge 4 ] && Display -h  "  6:  RAID6 -> Double parity: you loose 1/3 of total size of drives, you may loose two at a time"
          [ $NUM_PARTS -ge 5 ] && Display -h  "  7:  RAID7 -> Triple parity: you loose 1/3 of total size of drives, you may loose three at a time"
          
          read ZFS_TYPE
          
          [ $ZFS_TYPE -eq 0 -o $ZFS_TYPE -eq 1 -o $ZFS_TYPE -eq 5 -o $ZFS_TYPE -eq 6 -o $ZFS_TYPE -eq 7 ] && break
        done
      else
        ZFS_TYPE=0
      fi

      Display -h -n "You requested to build a "
      [ $ZFS_TYPE -eq 0 ] && echo -n "RAID0"
      [ $ZFS_TYPE -eq 1 ] && echo -n "RAID1"
      [ $ZFS_TYPE -eq 5 ] && echo -n "RAID5"
      [ $ZFS_TYPE -eq 6 ] && echo -n "RAID6"
      [ $ZFS_TYPE -eq 7 ] && echo -n "RAID7"
      Display -h " ZFS array using $ZFS_PARTS."

      COMMAND="zpool create -f Vstorage"
      [ $ZFS_TYPE -eq 1 ] && COMMAND="$COMMAND mirror"
      [ $ZFS_TYPE -eq 5 ] && COMMAND="$COMMAND raidz1"
      [ $ZFS_TYPE -eq 6 ] && COMMAND="$COMMAND raidz2"
      [ $ZFS_TYPE -eq 7 ] && COMMAND="$COMMAND raidz3"

      COMMAND="$COMMAND $ZFS_PARTS"
      Display -h "Creating pool..."
      $COMMAND || Error "ZFS pool creation failed,"
      
      Display -h "  Setting compression..."
      zfs set compression=lz4 Vstorage || Error "Cant set lz4 compression on Vstorage,"
      
      until false
      do
        Display -h "Checking Zpool Vstorage exists..."
        zpool status Vstorage >/dev/null 2>/dev/null || Error "Zpool Vstorage does not exist,"
        [ $? -eq 2 -o $? -eq 0 ] && break
      done

      Display -h "ZFS can be much faster reading adding ARC (cache), or much faster writing adding ZIL (logs)."
      Display -h "To be efficient, these *must* be on SSD drives. These can be hardware RAID1 to be even more faster."
      Display -n "To add ARC, please provide a partition name, else [RETURN]: "
      read ZFS_ARC
      if [ "x$ZFS_ARC" != "x" ]
      then
        Display -h "Adding $ZFS_ARC as ARC on Vstorage..."
        zpool add Vstorage cache $ZFS_ARC || Error "failed to add $ZFS_ARC,"
      fi  

      Display -n "To add ZIL, please provide a partition name, else [RETURN]: "
      read ZFS_ZIL
      if [ "x$ZFS_ZIL" != "x" ]
      then
        Display -h "Adding $ZFS_ZIL as ZIL on Vstorage..."
        zpool add Vstorage log $ZFS_ZIL || Error "failed to add $ZFS_ZIL,"
      fi

      Display -h "Final ZFS pool:"
      zpool status Vstorage
      zfs list Vstorage
      
      break
    done
  fi

  Display -h "Checking for ZFS pool..."
  zpool import -a -f >/dev/null 2>/dev/null
  zfs list Vstorage >/dev/null 2>/dev/null || Error 'ZFS pool Vstorage does not exists,'

  VIGRID_STORAGE_MODE="ZFS"

  Display -h "Now creating Vigrid NASless server datasets:"
  LIST="home/gns3/GNS3/projects home/gns3/GNS3/images var-lib-docker"
  for i in $LIST
  do
    zfs list Vstorage/$i >/dev/null 2>/dev/null
    if [ $? -ne 0 ] # dataset does not exist
    then
      Display -h "$i..."
      zfs create -p Vstorage/$i || Error "Cant create Vstorage/$i,"
    else
      Display -h "Vstorage/$i already created, skipping it..."
    fi
  done
else
  Display -h "Creating a fake /Vstorage tree to concentrate all Vigrid data..."
  mkdir -p /Vstorage /Vstorage/var-lib-docker /Vstorage/GNS3-automounts /Vstorage/tmp 2>/dev/null || Error 'mkdir failed,'
  
  # NAS(es) IP address/names ?
  Display "Adding Vigrid autoFS configuration to /etc/auto.master..."
  echo "
/Vstorage/GNS3-automounts /etc/auto.vigrid     --timeout=10
" >>/etc/auto.master || Error 'Action failed,'

  Display -h "Creating /etc/auto.vigrid autoFS file..."
  
  if [ $VIGRID_TYPE -eq 2 ] # Standalone+NAS
  then
    NAS_MOUNT="/Vstorage/NFS/$HOST/GNS3mount"
  else # A farm, whatever the farm
    NAS_MOUNT="/Vstorage/GNS3/GNS3farm"
  fi
    
  echo "#
# Vigrid autoFS configuration
#
# NFSv4+nolock to solve forgotten locks in nfs-kernel-server
* -vers=4,nolock,rw,async,hard,relatime,rsize=1048576,wsize=1048576,timeo=600,retrans=3,lookupcache=pos $VIGRID_NAS_SERVER_NAME:$NAS_MOUNT/&" >/etc/auto.vigrid  || Error 'Creation failed,'
fi

Display -h "Moving home to Vstorage..."
rsync -az --inplace /home /Vstorage/ >/dev/null 2>/dev/null
rm -rf /home  >/dev/null 2>/dev/null
ln -s /Vstorage/home / || Error 'Link failed,'
# To rego at the same location despite inode changed, else /tmp
cd $SCRIPT_CWD >/dev/null 2>/dev/null || cd /tmp >/dev/null 2>/dev/null

if [ $VIGRID_TYPE -ge 2 -a $VIGRID_TYPE -le 5 ] # Vigrid with NAS
then
  Display -h "Making dir & linking /home/gns3/GNS3 to automount zone"
  mkdir -p /home/gns3  >/dev/null 2>/dev/null || Error '/home/gns3 directory creation failed,'
  ln -s /Vstorage/GNS3-automounts/GNS3 /home/gns3/GNS3 || Error 'Link failed,'

  Display -h "Adding NAS Docker share to /etc/fstab"
  echo "$VIGRID_NAS_SERVER_NAME:/Vstorage/NFS/$HOST/var-lib-docker /Vstorage/var-lib-docker        nfs     rw,async,hard,relatime,rsize=1048576,wsize=1048576,timeo=600,retrans=3,lookupcache=pos 0 0" >>/etc/fstab

  Display -h "Mounting /var/lib/docker..."
  mount /Vstorage/var-lib-docker || Display -h "Cant mount /var/lib/docker, might generate issues later."

  echo "Reloading autofs..."
  service autofs reload
fi

if [ $VIGRID_TYPE -eq 1 ] # no NAS
then
  Display -h "Linking docker directory to ZFS..."
  ln -s /Vstorage/var-lib-docker /var/lib/docker || Error 'Link failed,'
fi

if [ $VIGRID_TYPE -ne 6 ]
then
  Display -h "Your GNS3 server will now be configured to Vigrid standards:"

  # Get physical NICs
  VIGRID_NICS=`ls -l /sys/class/net/ 2>/dev/null | egrep "pci[0-9]"| sed 's/->.*$//' | awk '{print $NF;}'`
  VIGRID_NICS=`echo $VIGRID_NICS`
  
  # Now get physical NICs with VLAN
  VIGRID_NICS_VLAN=""
  for i in $VIGRID_NICS
  do
    VLAN=`ls -l /sys/class/net/ 2>/dev/null | grep "\/virtual\/" | sed 's/->.*$//' | egrep "$i.[0-9]{1,4}" | awk '{print $NF;}'`
    if [ "x$VLAN" != "x" ]
    then
      VIGRID_NICS_VLAN="$VIGRID_NICS_VLAN "$VLAN
    fi
  done
  VIGRID_NICS=`echo $VIGRID_NICS $VIGRID_NICS_VLAN`

  TEXT_DESIGN=""
  if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ] # Vigrid slave, hiding free network design
  then
    TEXT_DESIGN="

    -> Vigrid Slave !! Please select the same design as on its Vigrid Master."
  fi

  TEXT_DESIGN="$TEXT_DESIGN
    Please select:
      1- No network configuration change, you will manage everything
      2- TINY Cyber Range network configuration (requires 4 network interfaces: WAN, Admin, Blue, Red)
      3- FULL Cyber Range network configuration (requires 6 network interfaces: WAN, SuperAdmin, BlueAdmin, RedAdmin, Blue, Red)"

  until false
  do
    Display -h "
    Vigrid standard Network designs.

    NOTA: Vigrid Cyber Range designs removes netplan.io to revert to ifup (/etc/network/interfaces).

  $TEXT_DESIGN

      
    Available detected network interfaces: $VIGRID_NICS

    Your choice: "
    read VIGRID_NETWORK
    
    [ $VIGRID_NETWORK -ge 1 -a $VIGRID_NETWORK -le 3 ] && break
  done

  if [ $VIGRID_NETWORK -ne 1 ]
  then
    VIGRID_NIC_WAN=""
    VIGRID_NIC_SUPERADMIN=""
    VIGRID_NIC_BLUEADMIN=""
    VIGRID_NIC_BLUEEXPOSED=""
    VIGRID_NIC_REDADMIN=""
    VIGRID_NIC_REDEXPOSED=""

    VIGRID_NIC_FREE=$VIGRID_NICS

    until false
    do
      VIGRID_NIC_FREE_TEXT=""
      for i in $VIGRID_NIC_FREE
      do
        NIC_IP_FULL=`ip addr show $i|grep "inet" |grep -v "inet6"|head -1| awk '{print $2;}'`
        NIC_IP=`echo "$NIC_IP_FULL"| awk 'BEGIN { FS="/"; } {print $1;}'`
        NIC_STATUS=`ip link show $i|sed 's/^.* state //' | sed 's/ .*$//'`
        
        if [ "x$NIC_IP" != "x" ]
        then
          VIGRID_NIC_FREE_TEXT="$VIGRID_NIC_FREE_TEXT, $i ($NIC_STATUS,$NIC_IP)"
        elif [ "x$NIC_STATUS" != "x" ]
        then
          VIGRID_NIC_FREE_TEXT="$VIGRID_NIC_FREE_TEXT, $i ($NIC_STATUS)"
        else
          VIGRID_NIC_FREE_TEXT="$VIGRID_NIC_FREE_TEXT, $i"
        fi
        
      done
      Display -h "Available free network interfaces: $VIGRID_NIC_FREE_TEXT"

      [ "x$VIGRID_NIC_REDEXPOSED" = "x" ] && NIC_TYPE="Nred_exposed0"
      [ "x$VIGRID_NIC_BLUEEXPOSED" = "x" ] && NIC_TYPE="Nblue_exposed0"
      [ $VIGRID_NETWORK -eq 3 -a "x$VIGRID_NIC_REDADMIN" = "x" ] && NIC_TYPE="Nred_admin0"
      [ $VIGRID_NETWORK -eq 3 -a "x$VIGRID_NIC_BLUEADMIN" = "x" ] && NIC_TYPE="Nblue_admin0"
      [ "x$VIGRID_NIC_SUPERADMIN" = "x" ] && NIC_TYPE="Nsuperadmin0"
      [ "x$VIGRID_NIC_WAN" = "x" ] && NIC_TYPE="WAN"

      Display -h -n "Select network interface for $NIC_TYPE: "
      read NIC_ANSWER
      
      CHK=`echo $VIGRID_NIC_FREE| grep "$NIC_ANSWER" | wc -l`
      if [ $CHK -eq 0 ]
      then
        Display -h "(!!) Error, cant find free network interface $NIC_ANSWER"
      else
        [ "$NIC_TYPE" = "WAN" ] && VIGRID_NIC_WAN=$NIC_ANSWER
        [ "$NIC_TYPE" = "Nsuperadmin0" ] && VIGRID_NIC_SUPERADMIN=$NIC_ANSWER
        [ "$NIC_TYPE" = "Nblue_admin0" ] && VIGRID_NIC_BLUEADMIN=$NIC_ANSWER
        [ "$NIC_TYPE" = "Nred_admin0" ] && VIGRID_NIC_REDADMIN=$NIC_ANSWER
        [ "$NIC_TYPE" = "Nblue_exposed0" ] && VIGRID_NIC_BLUEEXPOSED=$NIC_ANSWER
        [ "$NIC_TYPE" = "Nred_exposed0" ] && VIGRID_NIC_REDEXPOSED=$NIC_ANSWER

        VIGRID_NIC_FREE=`echo "$VIGRID_NIC_FREE "| sed "s/$NIC_ANSWER //g"`

        if [ "x$VIGRID_NIC_REDEXPOSED" != "x" -a "x$VIGRID_NIC_BLUEEXPOSED" != "x" -a "x$VIGRID_NIC_SUPERADMIN" != "x" -a "x$VIGRID_NIC_WAN" != "x" ]
        then
          if [ $VIGRID_NETWORK -eq 3 ]
          then
            [ "x$VIGRID_NIC_REDADMIN" != "x" -a "x$VIGRID_NIC_BLUEADMIN" != "x" ] && break
          else
            break
          fi
        fi
      fi
    done
  fi

  # Display "Getting host network configuration (static IP+routes or DHCP, DNS & default route), first NIC with IP as a reference"
  # HOST_NIC=`ip addr show up | grep "^[0-9]" | egrep -v "(virbr0|docker0|lo):"| awk '{print $2;}'| sed 's/://g'`

  # for i in $HOST_NIC
  # do
    # HOST_NIC_DHCP=`ip addr show $i|grep "inet.*dynamic" |head -1| awk '{print $2;}' | grep -v "::" | tr -s ' '`
    # HOST_NIC_IP_FULL=`ip addr show $i|grep "inet" |head -1| awk '{print $2;}' | grep -v "::" | tr -s ' '`
    # HOST_NIC_IP=`echo "$HOST_NIC_IP_FULL"| awk 'BEGIN { FS="/"; } {print $1;}'`
    
    # [ "x$HOST_NIC_DHCP" != "x" -o "x$HOST_NIC_IP" != "x" ] && break
  # done

  # HOST_DHCP=$HOST_NIC_DHCP
  # HOST_IP_FULL=$HOST_NIC_IP_FULL
  # HOST_IP=$HOST_NIC_IP

  # HOST_ROUTE=`ip route |grep default|awk '{print $3;}'`

  # HOST_DNS=`systemd-resolve --status | grep 'Current DNS Server:'| awk '{print $NF;}'`
  # [ "x$HOST_DNS" = "x" ] && HOST_DNS=`dig github.com +short +identify | awk '{print $4;}'`
  # HOST_DNS=`echo $HOST_DNS`

  [ "x$HOST_DHCP" != "x" ] && Display -h "Host is DHCP client"
  Display -h "Host IP is $HOST_IP ($HOST_IP_FULL), DNS is $HOST_DNS, default route via $HOST_ROUTE"

  # Vigrid slave, Cyber Range design then enforced
  if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ]
  then
    if [ $VIGRID_NETWORK -ne 1 ]
    then
      CHK=`which ipcalc`
      [ "x$CHK" = "x" ] && Display "Installing ipcalc" && ( apt install -y ipcalc || Error 'Install failed,' )
      
      until false
      do
        Display -n "Vigrid Slave, please provide an free IP address on Nsuperadmin0 (172.29.0.0/24): "
        read VIGRID_SLAVE_IP
        
        CHK=`sipcalc $VIGRID_SLAVE_IP|grep "^-\[ERR : "|wc -l`
        if [ $CHK -eq 0 ]
        then
          CHK=`echo $VIGRID_SLAVE_IP|grep "172\.29\.0\.254"`
          if [ "x$CHK" = "x" ]
          then
            CHK=`echo $VIGRID_SLAVE_IP|grep "172\.29\.0\."`
            [ "x$CHK" != "x" ] && break
          fi
          Display -h "I am sorry, IP address must be in Nsuperadmin0 (172.29.0.0/24) and not 172.29.0.254 (Master)"
        fi
      done
    else
      # No network management, using default IP
      VIGRID_SLAVE_IP=$HOST_IP
    fi
    
    echo "Reloading autofs..."
    service autofs reload
  fi
else
  VIGRID_NETWORK=1 
fi # VIGRIDsolo

Display "Ok, let's start the GNS3 and associated software now..."

Display -h "Adding miscellaneous packages..."
apt install -y iotop atop sysstat rsync rclone openntpd ntpdate jq libimage-imlib2-perl libnet-vnc-perl || Error "Failed,"

Display "Creating gns3 group..." && groupadd -g 777 -f gns3  2>/dev/null || Error 'Group creation failed,'
Display -h "Creating gns3 user..." && useradd -u 777 -d /home/gns3 -m -g gns3 gns3 2>/dev/null || Error 'User creation failed,'

Display "Adding GNS3 repository..." && add-apt-repository -y ppa:gns3/ppa || Error "Failed,"
Display "Updating system..." && apt update || Error "Update failed,"
Display "Installing GNS3 server..." && apt install -y gns3-server || Error "GNS3 server install failed,"
mkdir /var/log/gns3 >/dev/null 2>/dev/null
mkdir -p /home/gns3/.config/GNS3 >/dev/null 2>/dev/null
chown -R gns3:gns3 /var/log/gns3 /home/gns3 /home/gns3/GNS3 /home/gns3/GNS3/* >/dev/null 2>/dev/null

# In case user said no to GNS3 sniffing for all users...
setcap cap_net_admin,cap_net_raw=ep /usr/bin/ubridge

# GNS3 credentials
GNS3_USER="gns3"
# Vigrid slave, GNS3 password comes from master
if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ]
then
  until false
  do
    Display -n "Vigrid Slave, please provide the GNS3 password taken from Master Server: "
    read GNS3_PASS
    
    [ "x$GNS3_PASS" != "x" ] && break
  done
else
  Display -h "Generating GNS3 password..."
  GNS3_PASS=`openssl rand -base64 32 | tr -dc '[:alnum:]' | cut -c 1-20`
fi

Display -h "Setting gns3 user password same as GNS3 itself..."
echo "gns3:$GNS3_PASS" | chpasswd

# Cyber Range designs
GNS3_IP="127.0.0.1"
GNS3_NIC_NAT="virbr0"

if [ $VIGRID_NETWORK -eq 2 -o $VIGRID_NETWORK -eq 3 ]
then
  [ $VIGRID_NETWORK -eq 2 ] && GNS3_NIC="virbr0,Nred_exposed0,Nblue_exposed0"
  [ $VIGRID_NETWORK -eq 3 ] && GNS3_NIC="virbr0,Nred_exposed0,Nred_admin0,Nblue_exposed0,Nblue_admin0"
else
  T=`echo $HOST_NIC| sed 's/ /,/g'`
  GNS3_NIC="virbr0,$T"
fi

# GNS slave, IP address in Nsuperadmin0
if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ]
then
  GNS3_IP=$VIGRID_SLAVE_IP
fi

Display "Creating /home/gns3/.config/GNS3/gns3_server.conf with host=$GNS3_IP, user=$GNS3_USER, pass=$GNS3_PASS..."

echo ";
; GNS3 Server Configuration file
;
[Server]
;
auto_start = True
allow_console_from_anywhere = False

; IP where the server listen for connections
host = $GNS3_IP
; Protocol to use
protocol = http
; HTTP port for controlling the servers
port = 3080

; Option to enable HTTP authentication.
auth = True
; Username for HTTP authentication.
user = $GNS3_USER
; Password for HTTP authentication.
password = $GNS3_PASS

; Path to GNS3 Server
path = /usr/bin/gns3server

; Path where devices images are stored
images_path = /home/gns3/GNS3/images

; Path where user projects are stored
projects_path = /home/gns3/GNS3/projects

; Path where user appliances are stored
appliances_path = /home/gns3/GNS3/appliances

; Path where custom device symbols are stored
symbols_path = /home/gns3/GNS3/symbols

; Option to automatically send crash reports to the GNS3 team
report_errors = True

; First console port of the range allocated to devices
console_start_port_range = 5000
; Last console port of the range allocated to devices
console_end_port_range = 20000
; First port of the range allocated for inter-device communication. Two ports are allocated per link.
udp_start_port_range = 5000
; Last port of the range allocated for inter-device communication. Two ports are allocated per link
udp_end_port_range = 20000
; uBridge executable location, default: search in PATH
ubridge_path = /usr/bin/ubridge

; Only allow these interfaces to be used by GNS3, for the Cloud node for example (Linux/OSX only)
; Do not forget to allow virbr0 in order for the NAT node to work
allowed_interfaces = $GNS3_NIC

; Specify the NAT interface to be used by the NAT node
; Default is virbr0 on Linux (requires libvirt) and vmnet8 for other platforms (requires VMware)
default_nat_interface = $GNS3_NIC_NAT

[VPCS]
; VPCS executable location, default: search in PATH
;vpcs_path = vpcs

[Dynamips]
; Enable auxiliary console ports on IOS routers
allocate_aux_console_ports = False
mmap_support = True

; Dynamips executable path, default: search in PATH
;dynamips_path = dynamips
sparse_memory_support = True
ghost_ios_support = True

[IOU]
; Path of your .iourc file. If not provided, the file is searched in $HOME/.iourc
iourc_path = /home/gns3/.iourc
; Validate if the iourc license file is correct. If you turn this off and your licence is invalid IOU will not start and no errors will be shown.
license_check = True

[Qemu]
; !! Remember to add the gns3 user to the KVM group, otherwise you will not have read / write permissions to /dev/kvm !! (Linux only, has priority over enable_hardware_acceleration)
enable_kvm = True
; Require KVM to be installed in order to start VMs (Linux only, has priority over require_hardware_acceleration)
require_kvm = True

; Enable hardware acceleration (all platforms)
enable_hardware_acceleration = True
; Require hardware acceleration in order to start VMs (all platforms)
require_hardware_acceleration = False

" >/home/gns3/.config/GNS3/gns3_server.conf || Error 'Cant create /home/gns3/.config/GNS3/gns3_server.conf,'

mkdir -p /home/gns3/bin /home/gns3/etc >/dev/null 2>/dev/null
chmod 775 /home/gns3/etc >/dev/null 2>/dev/null

Display "Installing Vigrid extensions via /home/gns3/bin/vigrid-update"
LIST=""
i=""

echo '#!/bin/sh

echo Vigrid update script

UID=`id -u`

if [ "x$UID" != "x0" ]
then
  echo "I need root privileges please"
  exit 1
fi

CHK=`which git`
[ "x$CHK" = "x" ] && apt install -y git

VIGRID_HOME=""
if [ -d /home/gns3/vigrid ]
then
  VIGRID_HOME="/home/gns3/vigrid"
elif [ -d /Vstorage/home/gns3/vigrid ]
then
  VIGRID_HOME="/Vstorage/home/gns3/vigrid"
elif [ -d /Vstorage/GNS3/vigrid ]
then
  VIGRID_HOME="/Vstorage/GNS3/vigrid"
fi

echo "Vigrid home is $VIGRID_HOME"

if [ "x$VIGRID_HOME" != "x" ]
then
  cd $VIGRID_HOME && git config --global --add safe.directory $VIGRID_HOME && git pull || echo Vigrid update failed
  echo "Resetting $VIGRID_HOME permissions (need root privilege)..."
  chown -R gns3:gns3 $VIGRID_HOME >/dev/null 2>/dev/null
else
  cd /home/gns3 && git clone https://github.com/llevier/vigrid.git || echo Vigrid update failed
  chown -R gns3:gns3 /home/gns3/vigrid >/dev/null 2>/dev/null
fi

VIGRID_CONFIG="/home/gns3/etc/vigrid.conf"
[ -f $VIGRID_CONFIG ] && . $VIGRID_CONFIG

[ "x$VIGRID_TYPE" = "x" ] && VIGRID_TYPE=0

if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 5 ]
then
  chown 0:0 /home/gns3/vigrid/etc/sudoers
fi

if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 3 ]
then
  echo
  echo Vigrid updated, please pay attention to sudoers file...

  echo
  echo Reloading daemon details
  systemctl daemon-reload

  echo
  echo Restarting services...
  LIST="vigrid-noconsoles vigrid-cloning"
  for i in $LIST
  do
    echo "  $i..."
    
    CHK=`systemctl list-unit-files|grep "^$i.service"`
    if [ "x$CHK" = "x" ]
    then
      echo "does not exist in unit files, no action"
    else
      service $i stop
      service $i start
    fi
  done
fi

echo
echo All done
' >/home/gns3/bin/vigrid-update

chmod 755 /home/gns3/bin/vigrid-update || Error 'Cant chmod /home/gns3/bin/vigrid-update,'
Display -h "  Launching vigrid-update..."
/home/gns3/bin/vigrid-update || Error 'vigrid-update failed,'

if [ $VIGRID_TYPE -ne 1 -a $VIGRID_TYPE -ne 6 ]
then
  Display -h "Creating /home/gns3/etc/auto.vigrid file for autofs..."
  cat /home/gns3/vigrid/etc/auto.vigrid.sample >/home/gns3/etc/auto.vigrid || Error 'Creating failed,'
fi

Display -h "  $VIGRID_CONF"
VIGRID_MYSQL_PASS=`openssl rand -base64 32 | tr -dc '[:alnum:]' | cut -c 1-20`

# SSH Keys for NAS & Slaves (if any)
VIGRID_SSHKEY_GNS="/home/gns3/etc/id_GNS3"

if [ $VIGRID_TYPE -eq 3 ]
then
  Display "Generating SSH key for Slaves control (no password)" && ssh-keygen -N "" -f $VIGRID_SSHKEY_GNS || Error 'generation failed,'
fi

# Extracting GNS3 version
VIGRID_GNS_VERSION=`dpkg --list|grep gns3-server|awk '{print $3;}'| sed 's/~.*$//'| awk -F '.' '{print $1;}'`

echo "#
# Vigrid configuration file
#

# Vigrid Type: 1=Standalone, 2=Standalone+NAS, 3=GNS3farmMaster+NAS, 4=GNS3farmSlave+NAS, 5=GNS3scalableSlave+NAS
VIGRID_TYPE=$VIGRID_TYPE

# Vigrid Network design: 2=Tiny CyberRange (4 NICs), 5=Normal Cyber Range (6 NICs)
VIGRID_NETWORK=$VIGRID_NETWORK

# GNS3 version
VIGRID_GNS_VERSION=$VIGRID_GNS_VERSION

# NAS IP address/hostname for NAS dependant servers">$VIGRID_CONF

[ "x$VIGRID_NAS_SERVER_IP" != "x" ] && echo "VIGRID_NAS_SERVER=\"$VIGRID_NAS_SERVER_NAME:$VIGRID_NAS_SERVER_IP\"" >>$VIGRID_CONF
[ "x$VIGRID_NAS_SERVER_IP" != "x" ] || echo "# VIGRID_NAS_SERVER=HostName:IPaddress" >>$VIGRID_CONF

if [ $VIGRID_TYPE -eq 1 ]
then
  echo "VIGRID_STORAGE_MODE=\"ZFS\"" >>$VIGRID_CONF
  echo "VIGRID_STORAGE_ROOT=\"/Vstorage\"" >>$VIGRID_CONF
else
  if [ "x$VIGRID_STORAGE_MODE" != "x" ]
  then
    echo "VIGRID_STORAGE_MODE=\"$VIGRID_STORAGE_MODE\"" >>$VIGRID_CONF
  else
    echo "# VIGRID_STORAGE_MODE=\"ZFS|BTRfs\"" >>$VIGRID_CONF
  fi

  if [ "x$VIGRID_STORAGE_ROOT" != "x" ]
  then
    echo "VIGRID_STORAGE_ROOT=\"$VIGRID_STORAGE_ROOT\"" >>$VIGRID_CONF
  else
    echo "# VIGRID_STORAGE_ROOT=\"/directory\"" >>$VIGRID_CONF
  fi
fi

echo "
# DHCP Server (if not local)
# VIGRID_DHCP_SERVER=hostname:IPaddress

# NAS SSH key for DHCP server
# VIGRID_SSHKEY_DHCP=path_to_ssh_key

# GNS3 Credentials
VIGRID_GNS_USER=$GNS3_USER
VIGRID_GNS_PASS=$GNS3_PASS

# MySQL credentials for Vigrid Cloning Daemon
VIGRID_MYSQL_USER=vigrid
VIGRID_MYSQL_PASS=$VIGRID_MYSQL_PASS
">>$VIGRID_CONF

echo "VIGRID_MYSQL_HOST=\"localhost\"" >>$VIGRID_CONF
# if [ $VIGRID_TYPE -eq 1 -o $VIGRID_TYPE -eq 2 -o $VIGRID_TYPE -eq 3 ]
# then
  # echo "VIGRID_MYSQL_HOST=\"localhost\"" >>$VIGRID_CONF
# else
  # echo "VIGRID_MYSQL_HOST=\"172.29.0.254\"" >>$VIGRID_CONF
# fi

echo "
# Hostname:IPaddress:port of MX hub to send emails (cloning center)
VIGRID_SMTP_RELAY=\"localhost:127.0.0.1:25\"
VIGRID_SMTP_MAILFROM=\"noreply@$HOST\"

# Websockify options (if required)
VIGRID_WEBSOCKIFY_OPTIONS=\"--timeout=300\"

# SSH options for all ssh actions
VIGRID_SSHKEY_OPTIONS=\"-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\"

# NAS SSH key for automated authentication
VIGRID_SSHKEY_NAS=$VIGRID_SSHKEY_NAS

# GNS3 servers (upon Master of a farm, either slaves or scalable)
VIGRID_SSHKEY_GNS=$VIGRID_SSHKEY_GNS

# Remote console (iDRAC, iLo, IMM etc) credentials for remote power on enslaved servers
# VIGRID_POWER_USER=
# VIGRID_POWER_PASS=
# VIGRID_POWER_ACCESS=(IPMI|SSH)

">>$VIGRID_CONF

if [ $VIGRID_TYPE -eq 2 -o $VIGRID_TYPE -eq 3 ]
# Master server
then
  echo "
# GNS3 hosts (slaves or scalable servers). Format: hostname:IP:port hostname:IP:port...
# GNS3 credentials *must* be the same as on master host
# VIGRID_GNS_SLAVE_HOSTS=
">>$VIGRID_CONF
fi

# Sanity GNS3 cleaning
chown -R gns3:gns3 /home/gns3 >/dev/null 2>/dev/null
chmod 660 $VIGRID_CONF >/dev/null 2>/dev/null

Display "Linking gns3_controller.conf to GNS3 central data..."
ln -s /home/gns3/GNS3/gns3_controller.conf /home/gns3/.config/GNS3/gns3_controller.conf || Error 'Link failed,'

LIST="gns3"
if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ]
then
  LIST="$LIST vigrid-noconsoles vigrid-cloning"
fi

Display -n "Linking/enabling Vigrid/GNS3 services..."
for i in $LIST
do
  Display -h -n "$i "
  cp /home/gns3/vigrid/lib/systemd/system/$i.service /lib/systemd/system/$i.service || Error "Copy $i failed,"

  systemctl enable $i || Error "Enabling $i service failed,"
done

Display "Cleaning possible docker presence..." && apt remove -y docker docker-engine docker.io
Display "Adding required packages for Docker..." && apt install -y apt-transport-https ca-certificates curl software-properties-common || Error "Failed,"
install -m 0755 -d /etc/apt/keyrings
Display "Adding Docker repo key..." && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc || Error "Failed,"
chmod a+r /etc/apt/keyrings/docker.asc
Display "Adding Docker repo..." && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
[ $? -ne 0 ] && Error 'Add failed,'
  
Display "Updating system..." && apt update -y
Display "Installing Docker..." && apt install -y docker-ce || Error "Failed,"
Display "Stopping Docker service..." && service docker stop

Display -h "Now ensuring users & groups are ok..."
usermod -a gns3 -G gns3 >/dev/null 2>/dev/null
usermod -a gns3 -G ubridge >/dev/null 2>/dev/null
usermod -a gns3 -G docker >/dev/null 2>/dev/null
usermod -a gns3 -G libvirt >/dev/null 2>/dev/null
usermod -a gns3 -G kvm >/dev/null 2>/dev/null
usermod -a gns3 -G wireshark >/dev/null 2>/dev/null

usermod -a ubridge -G gns3 >/dev/null 2>/dev/null
usermod -a ubridge -G docker >/dev/null 2>/dev/null

usermod -a libvirt -G gns3 >/dev/null 2>/dev/null
usermod -a libvirt -G docker >/dev/null 2>/dev/null

usermod -a kvm -G gns3 >/dev/null 2>/dev/null
usermod -a kvm -G docker >/dev/null 2>/dev/null

usermod -a wireshark -G gns3 >/dev/null 2>/dev/null

usermod -a docker -G gns3 >/dev/null 2>/dev/null
usermod -a docker -G ubridge >/dev/null 2>/dev/null
usermod -a docker -G libvirt >/dev/null 2>/dev/null
usermod -a docker -G kvm >/dev/null 2>/dev/null
usermod -a docker -G wireshark >/dev/null 2>/dev/null
usermod -a docker -G docker >/dev/null 2>/dev/null

Display -h "Adding docker overlay configuration file..."
if [ $VIGRID_TYPE -eq 1 ]
then
  [ "x$VIGRID_STORAGE_MODE" = "xZFS" ] && DRIVER="zfs"
  [ "x$VIGRID_STORAGE_MODE" = "xBTRfs" ] && DRIVER="btrfs"
else
  DRIVER="overlay2"
fi

echo "{
  \"storage-driver\": \"$DRIVER\",
  \"data-root\": \"/var/lib/docker\"
}" >/etc/docker/daemon.json

Display -h "Cleaning docker directory..."
rm -rf /var/lib/docker/* 2>/dev/null

Display -h "Updating /etc/sysctl.conf (changes at top of file, preventive copy done) to disable IPv6 and add IP forward..."
cp /etc/sysctl.conf /etc/sysctl.conf.old
echo "# GNS3 Bridge forward (mandatory)
net.ipv4.ip_forward=1

# Disabling IPv6 as well
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
" >/tmp/temp$$
cat /etc/sysctl.conf >>/tmp/temp$$
mv /tmp/temp$$ /etc/sysctl.conf || Error "Failed,"

Display "Disabling IPv6 at grub level as well..."
cp /etc/default/grub /etc/default/grub.org
cat /etc/default/grub \
  | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"ipv6.disable=1 /' \
  | sed 's/^GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"ipv6.disable=1 /' >/tmp/grub.tmp
mv /tmp/grub.tmp /etc/default/grub || Error 'Cant replace /etc/default/grub,'
if [ $VIGRID_TYPE -ne 6 ]
then
  Display -h "Updating grub..."
  update-grub || Error 'update-grub failed,'
fi

Display "Creating KVM kernel modules..."
echo "options kvm_intel nested=1
options kvm_amd nested=1
">/etc/modprobe.d/kvm.conf
ln -s /etc/modprobe.d/kvm.conf /etc/modprobe.d/kvm_amd.conf
ln -s /etc/modprobe.d/kvm.conf /etc/modprobe.d/kvm_intel.conf

# Qemu version
/home/gns3/vigrid/bin/qemu-update || Error 'Cant launch qemu-update'

Display "Adding i386 compat for IOU..." && dpkg --add-architecture i386 || Error "Failed,"
Display "Updating system..." && apt update -y || Error 'Update failed,'
Display "Installing IOU..." && apt install -y gns3-iou || Error "Failed,"

if [ $VIGRID_NETWORK -eq 2 -o $VIGRID_NETWORK -eq 3 ] # Network design to Vigrid
then
  Display "Installing Vigrid network configuration..."

  # netplan is not able to have 2 bridges over the same bond
  Display -h "Removing netplan.io for old ifup..."
  apt install -y ifenslave vlan ifupdown bridge-utils || Error "Failed to add ifenslave vlan ifupdown bridge-utils packages,"
  apt remove -y netplan.io && apt autoremove -y

  until false
  do
    Display -h "All NICs will be bound, permitting you to aggregate.
  See https://www.thegeekdiary.com/what-are-the-network-bonding-modes-in-centos-rhel/ for details.    

  What do you prefer as failover mecanism ?
    0- Round Robin
    1- Active Backup    
    2- XOR [exclusive OR]
    4- Dynamic Link Aggregation/LACP, will require a properly configured LACP switch
    5- Transmit Load Balancing (TLB)
    6- Adaptive Load Balancing (best choice, default)

  Your choice ? "
    read VIGRID_NETWORK_BOND

    if [ "x$VIGRID_NETWORK_BOND" = "x" ]
    then
      Display -h 'Ok, will consider you selected 6, best choice'
      VIGRID_NETWORK_BOND=6
      break
    fi

    if [ $VIGRID_NETWORK_BOND -ne 3 ]
    then
      [ $VIGRID_NETWORK_BOND -ge 0 -a $VIGRID_NETWORK_BOND -le 6 ] && break
    fi
  done

  # [ $VIGRID_NETWORK_BOND -ge 0 ] && VIGRID_NETWORK_BOND="balance-rr"
  # [ $VIGRID_NETWORK_BOND -ge 1 ] && VIGRID_NETWORK_BOND="active-backup"
  # [ $VIGRID_NETWORK_BOND -ge 2 ] && VIGRID_NETWORK_BOND="balance-xor"
  # [ $VIGRID_NETWORK_BOND -ge 3 ] && VIGRID_NETWORK_BOND="broadcast"
  # [ $VIGRID_NETWORK_BOND -ge 4 ] && VIGRID_NETWORK_BOND="802.3ad"
  # [ $VIGRID_NETWORK_BOND -ge 5 ] && VIGRID_NETWORK_BOND="balance-tlb"
  # [ $VIGRID_NETWORK_BOND -ge 6 ] && VIGRID_NETWORK_BOND="balance-alb"

  Display "Creating /etc/network/interfaces..."

  echo "#
# Vigrid Cyber Range network interface configuration
#
# source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# Internet
auto $VIGRID_NIC_WAN
iface $VIGRID_NIC_WAN inet manual
        bond-master Binternet0

auto Binternet0
iface Binternet0 inet manual
        bond_miimon 100
        bond_mode $VIGRID_NETWORK_BOND
        bond-slaves $VIGRID_NIC_WAN

auto Ninternet0" >/etc/network/interfaces

  if [ "x$HOST_DHCP" != "x" ]
  then
    echo "iface Ninternet0 inet dhcp" >>/etc/network/interfaces
  else
    echo "iface Ninternet0 inet static
        address $HOST_IP_FULL" >>/etc/network/interfaces
        
    if [ "x$HOST_ROUTE" != "x" ]
    then
      echo "        gateway $HOST_ROUTE" >>/etc/network/interfaces
    fi

    if [ "x$HOST_DNS" != "x" ]
    then
      echo "        dns-nameservers "$HOST_DNS >>/etc/network/interfaces
    fi
  fi
  
  echo "        bridge_ports Binternet0
        bridge_stp off
        bridge_fd 0

# Cyber Range Deus
auto $VIGRID_NIC_SUPERADMIN
iface $VIGRID_NIC_SUPERADMIN inet manual
        bond-master Bsuperadmin0

auto Bsuperadmin0
iface Bsuperadmin0 inet manual
        bond_miimon 100
        bond_mode $VIGRID_NETWORK_BOND
        bond-lacp-rate 1
        bond-slaves $VIGRID_NIC_SUPERADMIN

auto Nsuperadmin0
iface Nsuperadmin0 inet static" >>/etc/network/interfaces

  if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ] # Slave
  then
    echo "        address $VIGRID_SLAVE_IP
        netmask 255.255.255.0
        gateway 172.29.0.254"  >>/etc/network/interfaces
  else
    echo "        address 172.29.0.254
        netmask 255.255.255.0"  >>/etc/network/interfaces
  fi

echo "        bridge_ports Bsuperadmin0
        bridge_stp off
        bridge_fd 0

# Blue exposed and users
auto $VIGRID_NIC_BLUEEXPOSED
iface $VIGRID_NIC_BLUEEXPOSED inet manual
        bond-master Bblue_exposed0

auto Bblue_exposed0
iface Bblue_exposed0 inet manual
        bond_miimon 100
        bond_mode $VIGRID_NETWORK_BOND
        bond-lacp-rate 1
        bond-slaves $VIGRID_NIC_BLUEEXPOSED

auto Nblue_exposed0" >>/etc/network/interfaces

  if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ] # Master, so gateway
  then
    echo "        iface Nblue_exposed0 inet static
        address 172.29.9.254
        netmask 255.255.254.0" >>/etc/network/interfaces
  else
    echo "        iface Nblue_exposed0 inet manual" >>/etc/network/interfaces
  fi

  echo "        bridge_ports Bblue_exposed0
        bridge_stp off
        bridge_fd 0 "  >>/etc/network/interfaces

  if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ] # Master, so gateway
  then
    echo "
auto Nblue_users0
iface Nblue_users0 inet static
        address 172.29.11.254
        netmask 255.255.254.0
        bridge_ports Bblue_exposed0
        bridge_stp off
        bridge_fd 0
" >>/etc/network/interfaces
  fi

  echo "
# Red exposed and users
auto $VIGRID_NIC_REDEXPOSED
iface $VIGRID_NIC_REDEXPOSED inet manual
        bond-master Bred_exposed0

auto Bred_exposed0
iface Bred_exposed0 inet manual
        bond_miimon 100
        bond_mode $VIGRID_NETWORK_BOND
        bond-lacp-rate 1
        bond-slaves $VIGRID_NIC_REDEXPOSED

auto Nred_exposed0" >>/etc/network/interfaces

  if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ] # Master, so gateway
  then
    echo "        iface Nred_exposed0 inet static
        address 172.29.13.254
        netmask 255.255.254.0"  >>/etc/network/interfaces
  else
    echo "        iface Nred_exposed0 inet manual" >>/etc/network/interfaces
  fi
  
  echo "        bridge_ports Bred_exposed0
        bridge_stp off
        bridge_fd 0
"  >>/etc/network/interfaces
        
  if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ] # Master, so gateway
  then
    echo "auto Nred_users0
iface Nred_users0 inet static
        address 172.29.15.254
        netmask 255.255.254.0
        bridge_ports Bred_exposed0
        bridge_stp off
        bridge_fd 0
" >>/etc/network/interfaces
  fi

  if [ $VIGRID_NETWORK -eq 3 ]
  then
    echo "# BlueAdmin
auto $VIGRID_NIC_BLUEADMIN
iface $VIGRID_NIC_BLUEADMIN inet manual
        bond-master Bblue_admin0

auto Bblue_admin0
iface Bblue_admin0 inet manual
        bond_miimon 100
        bond_mode $VIGRID_NETWORK_BOND
        bond-lacp-rate 1
        bond-slaves $VIGRID_NIC_BLUEADMIN

auto Nblue_admin0"  >>/etc/network/interfaces

    if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ] # Master, so gateway
    then
      echo "        iface Nblue_admin0 inet static
        address 172.29.3.254
        netmask 255.255.254.0
        bridge_ports Bblue_admin0"  >>/etc/network/interfaces
    else
      echo "        iface Nblue_admin0 inet manual" >>/etc/network/interfaces
    fi
    
    echo "        bridge_stp off
        bridge_fd 0

# RedAdmin
auto $VIGRID_NIC_REDADMIN
iface $VIGRID_NIC_REDADMIN inet manual
        bond-master Bred_admin0

auto Bred_admin0
iface Bred_admin0 inet manual
        bond_miimon 100
        bond_mode $VIGRID_NETWORK_BOND
        bond-lacp-rate 1
        bond-slaves $VIGRID_NIC_REDADMIN

auto Nred_admin0"  >>/etc/network/interfaces

    if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ] # Master, so gateway
    then
      echo "        iface Nred_admin0 inet static
        address 172.29.5.254
        netmask 255.255.254.0"  >>/etc/network/interfaces
    else
      echo "        iface Nred_admin0 inet manual" >>/etc/network/interfaces
    fi
    
    echo "        bridge_ports Bred_admin0
        bridge_stp off
        bridge_fd 0

" >>/etc/network/interfaces
  fi
fi

# Having to update systemd-resolved as well :-(
DNS_FILE="/etc/systemd/resolved.conf"
if [ -f $DNS_FILE -o "x$HOST_DNS" != "x" ]
then
  echo "DNS=$HOST_DNS" >>$DNS_FILE
fi

#
# From now, we will proceed step by step, applying (or not) depending on the Vigrid & network designs
#
Display "Installing packages required by Vigrid..." && apt install -y sudo sysstat

# Only for MASTER servers

# Dirty workaround to have a condition regrouping in shell
CND1=0
CND2=0
# [ $VIGRID_TYPE -eq 1 -o $VIGRID_TYPE -eq 2 -o $VIGRID_TYPE -eq 3 ] && CND1=1
[ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 5 ] && CND1=1
[ $VIGRID_NETWORK -eq 2 -o $VIGRID_NETWORK -eq 3 ] && CND2=1

if [ $CND1 -eq 1 -a $CND2 -eq 1 ] # Master with Cyber Range network design
then
  ### Cyber Range IP address plans, openvpn & network formats
  ## Servers
  OVPN_Nsuperadmin0="172.29.0.0 255.255.255.0"
  NET_Nsuperadmin0=`echo $OVPN_Nsuperadmin0| sed 's/ /\//g'`

  OVPN_Nblue_admin0="172.29.2.0 255.255.254.0"
  NET_Nblue_admin0=`echo $OVPN_Nblue_admin0| sed 's/ /\//g'`

  OVPN_Nred_admin0="172.29.4.0 255.255.254.0"
  NET_Nred_admin0=`echo $OVPN_Nred_admin0| sed 's/ /\//g'`

  OVPN_Nblue_exposed0="172.29.8.0 255.255.254.0"
  NET_Nblue_exposed0=`echo $OVPN_Nblue_exposed0| sed 's/ /\//g'`

  OVPN_Nred_exposed0="172.29.12.0 255.255.254.0"
  NET_Nred_exposed0=`echo $OVPN_Nred_exposed0| sed 's/ /\//g'`

  ## Users (directly plugged)
  # SuperAdmin 
  OVPN_Nsuperadmin_users0="172.29.1.0 255.255.255.0"
  NET_Nsuperadmin_users0=`echo $OVPN_Nsuperadmin_users0| sed 's/ /\//g'`

  OVPN_Nblue_users0="172.29.10.0 255.255.254.0"
  NET_Nblue_users0=`echo $OVPN_Nblue_users0| sed 's/ /\//g'`

  OVPN_Nred_users0="172.29.14.0 255.255.254.0"
  NET_Nred_users0=`echo $OVPN_Nred_users0| sed 's/ /\//g'`

  ## Users (VIGRIDteleport)
  # Servers blocks = 32@IP (29 usable)    8 blocks  1 C class
  NET_VIGRIDteleport_BLUEservers="172.29.16.0/255.255.255.0"
  NET_VIGRIDteleport_REDservers="172.29.17.0/255.255.255.0"

  NET_D_START=0
  for i in `seq 1 8`
  do
    TEXT="172.29.16.$NET_D_START 255.255.255.224"
    eval "OVPN_Oblue_servers${i}='$TEXT'"
    TEXT=`echo $TEXT| sed 's/ /\//g'`
    eval "NET_Oblue_servers${i}=$TEXT"

    # eval /bin/echo "OVPN_Oblue_servers$i: \${OVPN_Oblue_servers${i}} \(\${NET_Oblue_servers${i}}\)"

    TEXT="172.29.17.$NET_D_START 255.255.255.224"
    eval "OVPN_Ored_servers${i}='$TEXT'"
    TEXT=`echo $TEXT| sed 's/ /\//g'`
    eval "NET_Ored_servers${i}=$TEXT"

    # eval /bin/echo "OVPN_Ored_servers$i: \${OVPN_Ored_servers${i}} \(\${NET_Ored_servers${i}}\)"

    NET_D_START=$((NET_D_START+32))
  done

  # Users blocks   = 128@IP (125 usable)  8 blocks  4 C classes
  NET_VIGRIDteleport_BLUEusers="172.29.18.0/255.255.252.0"
  NET_VIGRIDteleport_REDusers="172.29.22.0/255.255.252.0"

  NET_C_START=18
  NET_D_START=0
  for i in `seq 1 8`
  do
    TEXT="172.29.$NET_C_START.$NET_D_START 255.255.255.128"
    eval "OVPN_Oblue_users${i}='$TEXT'"
    TEXT=`echo $TEXT| sed 's/ /\//g'`
    eval "NET_Oblue_users${i}=$TEXT"

    # eval /bin/echo "OVPN_Oblue_users$i: \${OVPN_Oblue_users${i}} \(\${NET_Oblue_users${i}}\)"

    TEXT="172.29.$((NET_C_START+4)).$NET_D_START 255.255.255.128"
    eval "OVPN_Ored_users${i}='$TEXT'"
    TEXT=`echo $TEXT| sed 's/ /\//g'`
    eval "NET_Ored_users${i}=$TEXT"

    # eval /bin/echo "OVPN_Ored_users$i: \${OVPN_Ored_users${i}} \(\${NET_Ored_users${i}}\)"

    if [ $NET_D_START -eq 0 ]
    then
      NET_D_START=128
    else
      NET_D_START=0
      NET_C_START=$(($NET_C_START+1))
    fi
  done

  if [ $VIGRID_TYPE -eq 1 -o $VIGRID_TYPE -eq 2 -o $VIGRID_TYPE -eq 3 ]
  then
    Display -h "Installing ISC DHCP server..." && apt install -y isc-dhcp-server || Error 'Install failed,'

    DHCP_HOST_DNS=`echo $HOST_DNS|sed 's/ /,/'`
    DHCP_HOST_DNS=`echo $DHCP_HOST_DNS`

    Display "Updating DHCP for an instance per NIC..."
    Display -h "  /etc/dhcp/dhcpd-Nsuperadmin0.conf."
    echo "#
# Nsuperadmin0 dhcpd.conf
#

pid-file-name \"/var/run/dhcpd-Nsuperadmin0.pid\";

default-lease-time 14400;
max-lease-time 86400;

ddns-update-style none;

subnet 172.29.0.0 netmask 255.255.255.0 {
  range 172.29.0.2 172.29.0.250;
  option routers 172.29.0.254;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name "cyber-range";
  option subnet-mask 255.255.255.0;
  option broadcast-address 172.29.0.255;
}" >/etc/dhcp/dhcpd-Nsuperadmin0.conf

    Display -h "  /etc/dhcp/dhcpd-Nred_exposed0.conf."
    echo "#
# Nred_exposed0 dhcpd.conf
#

pid-file-name \"/var/run/dhcpd-Nred_exposed0.pid\";

default-lease-time 14400;
max-lease-time 86400;

ddns-update-style none;

subnet 172.29.12.0 netmask 255.255.254.0 {
  range 172.29.12.2 172.29.13.250;
  option routers 172.29.13.254;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name "cyber-range";
  option subnet-mask 255.255.254.0;
  option broadcast-address 172.29.13.255;
}

subnet 172.29.14.0 netmask 255.255.254.0 {
  range 172.29.14.2 172.29.15.250;
  option routers 172.29.15.254;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name "cyber-range";
  option subnet-mask 255.255.254.0;
  option broadcast-address 172.29.15.255;
}" >/etc/dhcp/dhcpd-Nred_exposed0.conf

    #VIGRIDteleport
    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Ored_servers${i}}"

      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      NET_RANGE_START=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $(NF-2);}'`
      NET_ROUTER=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $NF;}'`
      NET_ROUTER_DECIMAL=`sipcalc $NET_ROUTER|grep "^Host address .decimal"|awk '{print $NF;}'`
      NET_RANGE_DECIMAL=$(($NET_ROUTER_DECIMAL-1))
      dec2ip $NET_RANGE_DECIMAL
      NET_RANGE_END=`echo $T|sed 's/^\.//'`
      TEXT="
# VIGRIDteleport (VIGRIDred_servers$i)
subnet $NET_BASE netmask $NET_MASK {
  range $NET_RANGE_START $NET_RANGE_END;
  option routers $NET_ROUTER;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name \"cyber-range\";
  option subnet-mask $NET_MASK;
  option broadcast-address $NET_BROADCAST;
}"
  
      echo "$TEXT" >>/etc/dhcp/dhcpd-Nred_exposed0.conf
    done

    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Ored_users${i}}"

      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      NET_RANGE_START=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $(NF-2);}'`
      NET_ROUTER=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $NF;}'`
      NET_ROUTER_DECIMAL=`sipcalc $NET_ROUTER|grep "^Host address .decimal"|awk '{print $NF;}'`
      NET_RANGE_DECIMAL=$(($NET_ROUTER_DECIMAL-1))
      dec2ip $NET_RANGE_DECIMAL
      NET_RANGE_END=`echo $T|sed 's/^\.//'`
      TEXT="
# VIGRIDteleport (VIGRIDred_users$i)
subnet $NET_BASE netmask $NET_MASK {
  range $NET_RANGE_START $NET_RANGE_END;
  option routers $NET_ROUTER;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name \"cyber-range\";
  option subnet-mask $NET_MASK;
  option broadcast-address $NET_BROADCAST;
}"
  
      echo "$TEXT" >>/etc/dhcp/dhcpd-Nred_exposed0.conf
    done

    Display -h "  /etc/dhcp/dhcpd-Nblue_exposed0.conf."
    echo "#
# Nblue_exposed0 dhcpd.conf
#

pid-file-name \"/var/run/dhcpd-Nblue_exposed0.pid\";

default-lease-time 14400;
max-lease-time 86400;

ddns-update-style none;

subnet 172.29.8.0 netmask 255.255.254.0 {
  range 172.29.8.2 172.29.9.250;
  option routers 172.29.9.254;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name "cyber-range";
  option subnet-mask 255.255.254.0;
  option broadcast-address 172.29.9.255;
}

subnet 172.29.10.0 netmask 255.255.254.0 {
  range 172.29.10.2 172.29.11.250;
  option routers 172.29.11.254;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name "cyber-range";
  option subnet-mask 255.255.254.0;
  option broadcast-address 172.29.11.255;
}" >/etc/dhcp/dhcpd-Nblue_exposed0.conf

    #VIGRIDteleport
    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Oblue_servers${i}}"

      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      NET_RANGE_START=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $(NF-2);}'`
      NET_ROUTER=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $NF;}'`
      NET_ROUTER_DECIMAL=`sipcalc $NET_ROUTER|grep "^Host address .decimal"|awk '{print $NF;}'`
      NET_RANGE_DECIMAL=$(($NET_ROUTER_DECIMAL-1))
      dec2ip $NET_RANGE_DECIMAL
      NET_RANGE_END=`echo $T|sed 's/^\.//'`
      TEXT="
# VIGRIDteleport (VIGRIDblue_servers$i)
subnet $NET_BASE netmask $NET_MASK {
  range $NET_RANGE_START $NET_RANGE_END;
  option routers $NET_ROUTER;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name \"cyber-range\";
  option subnet-mask $NET_MASK;
  option broadcast-address $NET_BROADCAST;
}"
  
      echo "$TEXT" >>/etc/dhcp/dhcpd-Nblue_exposed0.conf
    done

    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Oblue_users${i}}"

      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      NET_RANGE_START=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $(NF-2);}'`
      NET_ROUTER=`sipcalc $NET_BASE $NET_MASK|grep "^Usable"|awk '{print $NF;}'`
      NET_ROUTER_DECIMAL=`sipcalc $NET_ROUTER|grep "^Host address .decimal"|awk '{print $NF;}'`
      NET_RANGE_DECIMAL=$(($NET_ROUTER_DECIMAL-1))
      dec2ip $NET_RANGE_DECIMAL
      NET_RANGE_END=`echo $T|sed 's/^\.//'`
      TEXT="
    # VIGRIDteleport (VIGRIDblue_users$i)
subnet $NET_BASE netmask $NET_MASK {
  range $NET_RANGE_START $NET_RANGE_END;
  option routers $NET_ROUTER;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name \"cyber-range\";
  option subnet-mask $NET_MASK;
  option broadcast-address $NET_BROADCAST;
}"
  
      echo "$TEXT" >>/etc/dhcp/dhcpd-Nblue_exposed0.conf
    done

    if [ $VIGRID_TYPE -ne 5 -a $VIGRID_NETWORK -eq 3 ]
    then
      Display -h "  /etc/dhcp/dhcpd-Nred_admin0.conf."
      echo "#
# dhcpd-Nred_admin0 dhcpd.conf
#

pid-file-name \"/var/run/dhcpd-Nred_admin0.pid\";

default-lease-time 14400;
max-lease-time 86400;

ddns-update-style none;

subnet 172.29.4.0 netmask 255.255.254.0 {
  range 172.29.4.2 172.29.5.250;
  option routers 172.29.5.254;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name "cyber-range";
  option subnet-mask 255.255.254.0;
  option broadcast-address 172.29.5.255;
}" >/etc/dhcp/dhcpd-Nred_admin0.conf

      Display -h "  /etc/dhcp/dhcpd-Nblue_admin0.conf."
      echo "#
# Nblue_admin0 dhcpd.conf
#

pid-file-name \"/var/run/dhcpd-Nblue_admin0.pid\";

default-lease-time 14400;
max-lease-time 86400;

authoritative;

ddns-update-style none;

subnet 172.29.2.0 netmask 255.255.254.0 {
  range 172.29.2.2 172.29.3.250;
  option routers 172.29.3.254;
  option domain-name-servers $DHCP_HOST_DNS;
  option domain-name "cyber-range";
  option subnet-mask 255.255.254.0;
  option broadcast-address 172.29.3.255;
}" >/etc/dhcp/dhcpd-Nblue_admin0.conf
    fi

    DHCP_LIST="Nsuperadmin0 Nblue_exposed0 Nred_exposed0"
    [ $VIGRID_TYPE -ne 5 -a $VIGRID_NETWORK -eq 3 ] && DHCP_LIST="$DHCP_LIST Nblue_admin0 Nred_admin0"

    for i in $DHCP_LIST
    do
      echo "" >/etc/dhcp/dhcpd-$i"6".conf
      
      Display -h "  Creating service isc-dhcp-$i."
      echo "# isc-dhcp-server default configuration for $i

OPTIONS=\"-lf /var/lib/dhcp/dhcpd-$i.leases\"

INTERFACESv4=\"$i\"
INTERFACESv6=\"\"
" >/etc/default/isc-dhcp-server-$i

      touch /var/lib/dhcp/dhcpd-$i.leases
      cat /etc/init.d/isc-dhcp-server | sed "s/etc\/default\/isc-dhcp-server/etc\/default\/isc-dhcp-server-$i/g" \
       | sed "s/etc\/dhcp\/dhcpd/etc\/dhcp\/dhcpd-$i/g" >/etc/init.d/isc-dhcp-server-$i
      chmod 755 /etc/init.d/isc-dhcp-server-$i

      touch /var/lib/dhcp/dhcpd-$i.leases
      chgrp dhcpd /var/lib/dhcp
      chmod g+w /var/lib/dhcp

      Display -h "    Enabling it..."
      systemctl enable isc-dhcp-server-$i || Error 'Cant enable isc-dhcp-server-$i,'
    done
    
    Display -h "  Finally allowing new dhcpd in apparmor"
    L=`cat /etc/apparmor.d/usr.sbin.dhcpd | grep -n "capability " | grep -v "capability .*dac_override" |tail -1|awk '{print $1;}' | sed 's/://'`
    head -$L /etc/apparmor.d/usr.sbin.dhcpd >/tmp/usr.sbin.dhcpd.$$  || Error 'head: action failed,'
    echo "  capability dac_override," >>/tmp/usr.sbin.dhcpd.$$  || Error 'add dac_override: action failed,'
    
    TT=`cat /etc/apparmor.d/usr.sbin.dhcpd|wc -l`
    T=`echo $TT - $L | bc`
    
    tail -$T /etc/apparmor.d/usr.sbin.dhcpd \
     | sed 's|/etc/dhcpd{,6}.conf r,|/etc/dhcpd{,6}-N**.conf r,|' \
     | sed 's|/var/lib/dhcp/dhcpd{,6}.leases* lrw,|/var/lib/dhcp/dhcpd{,6}-N**.leases* lrw,|' \
     | sed 's|/{,var/}run/{,dhcp-server/}dhcpd{,6}.pid rw,|/{,var/}run/{,dhcp-server/}dhcpd{,6}-N**.pid rw,|' \
     >> /tmp/usr.sbin.dhcpd.$$ || Error 'tail: action failed,'
    mv /tmp/usr.sbin.dhcpd.$$ /etc/apparmor.d/usr.sbin.dhcpd || Error 'mv: action failed,'
    
    systemctl disable isc-dhcp-server
    rm -f /etc/init.d/isc-dhcp-server
  fi
else # MASTER OR STANDALONE SERVER
  Display "To be able to associate a Virtual machine with an IP address, Vigrid needs to access a DHCP server logs.
I can install such a server, but no other DHCP server must be present in the LANs where will be bound the virtual machines.
Else you will have to provide a DHCP server in the Vigrid configuration step."

  if [ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ]
  then
    if [ $VIGRID_NETWORK -eq 1 ]
    then
      until false
      do
        Display -h -n "Do you want me to just install DHCPd service with default configuration (your concern then) [Y/n] ? "
        read ANS
        
        [ "x$ANS" = "xy" -o "x$ANS" = "xY" -o "x$ANS" = "xn" -o "x$ANS" = "xN" -o "x$ANS" = "x" ] && break
      done

      if [ "x$ANS" = "xy" -o "x$ANS" = "xY" -o "x$ANS" = "x" ]
      then
        Display -h "Installing ISC DHCP server..." && apt install -y isc-dhcp-server || Error 'Install failed,'
      fi
    fi
  fi

  if [ $VIGRID_TYPE -eq 6 ]
  then
    Display -h "Installing ISC DHCP server..." && apt install -y isc-dhcp-server || Error 'Install failed,'
  fi
fi

Display "Installing WebSOcat..."
wget -qO /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
chmod 755 /usr/local/bin/websocat || Error 'Cant chmod websocat, mostly likely it did not install...'

Display "Installing PHP CLI..." && apt install -y php-cli || Error 'Install failed,'

# GNS3 independant server, either standalone or mastering a farm
if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 5 ]
then
  Display "Installing PHP FPM..." && apt install -y php-fpm || Error 'Install failed,'

  if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 3 ]
  then
    apt install -y php-curl php-mail php-net-smtp || Error 'Install failed,'
  fi

  Display -h "  Configuring PHP pools..."

  PHP_VER=`php -v|head -1|awk '{print $2;}'| awk 'BEGIN { FS="."; } { print $1"."$2; }'`
  Display -h "    PHP version is $PHP_VER."

  Display -h "    Removing default PHP pools..."
  rm /etc/php/$PHP_VER/fpm/pool.d/* || Error 'Cant remove pool,'

  Display -h "    Adding Vigrid standard pool..."
  cp /home/gns3/vigrid/confs/php/php-pfm-pool.d-vigrid-www.conf /etc/php/$PHP_VER/fpm/pool.d/vigrid-www.conf
  sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/php/$PHP_VER/fpm/pool.d/vigrid-www.conf

  Display -h "Enabling & starting PHP-FPM..."
  systemctl enable php$PHP_VER-fpm
  service php$PHP_VER-fpm stop
  service php$PHP_VER-fpm start

  # OpenResty for Vigrid extensions
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
  echo -n >/var/www/html/index.html

  cp /home/gns3/vigrid/confs/nginx/vigrid-auth.lua /etc/nginx/
  if [ $? -ne 0 ]
  then
    Error 'Cant copy vigrid-auth.lua, exiting'
    exit 1
  fi

  cp /home/gns3/vigrid/confs/nginx/vigrid-cors.conf /etc/nginx/
  if [ $? -ne 0 ]
  then
    Error 'Cant copy vigrid-cors.conf, exiting'
    exit 1
  fi

  # if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 4 ]
  # then
    # cp /home/gns3/vigrid/confs/nginx/vigrid-www-auth.conf /etc/nginx/sites/vigrid-www-auth.conf
    # if [ $? -ne 0 ]
    # then
      # Error 'Cant create vigrid-www-auth.conf from template, exiting'
      # exit 1
    # fi

    # sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/nginx/sites/vigrid-www-auth.conf
  # fi
  
  if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 3 ]
  then
    cp /home/gns3/vigrid/confs/nginx/vigrid-www-https-master.conf /etc/nginx/sites/CyberRange-443.conf
    if [ $? -ne 0 ]
    then
      Error 'Cant create CyberRange-443.conf from template, exiting'
      exit 1
    fi

    sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/nginx/sites/CyberRange-443.conf
  
    cp /home/gns3/vigrid/confs/nginx/vigrid-www-https-for_nas.conf /etc/nginx/sites/CyberRange-443-$VIGRID_NAS_SERVER_NAME.conf
    if [ $? -ne 0 ]
    then
      Error 'Cant create CyberRange-443.conf from template, exiting'
      exit 1
    fi

    sed -i "s/%%NAS_HOST%%/$VIGRID_NAS_SERVER_NAME/" /etc/nginx/sites/CyberRange-443-$VIGRID_NAS_SERVER_NAME.conf
    sed -i "s/%%NAS_IP%%/$VIGRID_NAS_SERVER_IP" /etc/nginx/sites/CyberRange-443-$VIGRID_NAS_SERVER_NAME.conf
  else
    # For Vigrid slave, Vigrid-API for loads
    cp /home/gns3/vigrid/confs/nginx/vigrid-CyberRange-443-api.conf /etc/nginx/sites/CyberRange-443-api.conf
    if [ $? -ne 0 ]
    then
      Error 'Cant create CyberRange-443-api.conf from template, exiting'
      exit 1
    fi

    sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/nginx/sites/CyberRange-443-api.conf
    sed -i 's/%%VIGRID_ROOT%%/\/home\/gns3\/vigrid/' /etc/nginx/sites/CyberRange-443-api.conf
    sed -i "s/%%VIGRID_API%%/vigrid-api/" /etc/nginx/sites/CyberRange-443-api.conf

  fi

  cp /home/gns3/vigrid/confs/nginx/nginx.conf /etc/nginx/nginx.conf
  if [ $? -ne 0 ]
  then
    Error 'Cant copy nginx.conf, exiting'
    exit 1
  fi

  Display -h "Adding www-data user to gns3 group..."
  usermod -a www-data -G gns3 >/dev/null 2>/dev/null || Error 'add failed,'

  Display -h "Generating SSL certificate for localhost..."
  mkdir -p /etc/nginx/ssl >/dev/null 2>/dev/null
  ( printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth") | openssl req -x509 -out /etc/nginx/ssl/localhost.crt -keyout /etc/nginx/ssl/localhost.key -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' || Error 'Certificate generation failed,'

  Display -h "Enabling & starting NGinx..."
  systemctl enable openresty
  service nginx openresty

  if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 3 ]
  then
    Display "Creating $VIGRID_PASSWD with a login/pass=vigrid/vigrid"
    echo "vigrid:{PLAIN}vigrid" >$VIGRID_PASSWD
    Display "Also adding gns3 credentials to $VIGRID_PASSWD"
    echo "$GNS3_USER:{PLAIN}$GNS3_PASS" >>$VIGRID_PASSWD
    chown gns3:gns3 $VIGRID_PASSWD >/dev/null 2>/dev/null
    chmod 640 $VIGRID_PASSWD >/dev/null 2>/dev/null

    Display "Installing clientless console requirements..."
    apt install -y novnc websockify || Error 'Cant install packages,'

    Display -h "Installing SSLh..." && apt install -y sslh || Error 'Install failed,'
    Display -h "  Updating SSLh starting script (bug in permission in /var/run/sslh) ..."
    systemctl disable --now sslh
    sed -i 's/^\[Service\].*$/&\nRuntimeDirectory=sslh/g' /usr/lib/systemd/system/sslh.service
    systemctl enable --now sslh
  fi

  # Cyber range network design on master server = network I/O gateway
  if [ $VIGRID_NETWORK -eq 2 -o $VIGRID_NETWORK -eq 3 ]
  then
    Display -h "  Configuring SSLh (with current IP=$HOST_IP)..."
    echo "
DAEMON_OPTS=\"--user=sslh --listen=$HOST_IP:443 --ssh=localhost:22 --openvpn=127.0.0.1:1194 --tls=127.0.0.1:443 --pidfile=/var/run/sslh/sslh.pid\"" >>/etc/default/sslh

    Display "Adding OpenVPN/EasyRSA for full network access..." && apt install -y openvpn easy-rsa || Error 'Install failed,'
    Display "Creating OpenVPN server configuration..."

    Display "Creating empty users DB for VIGRIDteleport: $VIGRID_PASSWD_TELEPORT"
    touch $VIGRID_PASSWD_TELEPORT

    Display -h "Creating Certificate Authority directory..." && make-cadir /etc/openvpn/certs || Error 'make-cadir failed,'
    cd /etc/openvpn/certs || Error 'Cant CD to /etc/openvpn/certs,'
    export EASYRSA_REQ_OU="Vigrid CyberRange"
    Display -h "  Initializing PKI" && /usr/share/easy-rsa/easyrsa init-pki || Error 'action failed,'
    Display -h "  Generating DH params..." && /usr/share/easy-rsa/easyrsa gen-dh || Error 'action failed,'
    
    Display "  Building CA (Certificate Authority): " && /usr/share/easy-rsa/easyrsa --batch build-ca nopass || Error 'action failed,'
    Display "  Building 'CyberRange' Server certificates:" && /usr/share/easy-rsa/easyrsa --batch build-server-full CyberRange nopass || Error 'action failed,'

    Display "  Building VIGRIDteleport & OpenVPN clients:"
    VIGRID_OPENVPN_CLIENTS="VIGRIDclient"
    # 128IP users blocks
    for i in `seq 1 8`; do VIGRID_OPENVPN_CLIENTS="$VIGRID_OPENVPN_CLIENTS VIGRIDred_users$i"; done
    for i in `seq 1 8`; do VIGRID_OPENVPN_CLIENTS="$VIGRID_OPENVPN_CLIENTS VIGRIDblue_users$i"; done

    # 16IP servers blocks
    for i in `seq 1 8`; do VIGRID_OPENVPN_CLIENTS="$VIGRID_OPENVPN_CLIENTS VIGRIDred_servers$i"; done
    for i in `seq 1 8`; do VIGRID_OPENVPN_CLIENTS="$VIGRID_OPENVPN_CLIENTS VIGRIDblue_servers$i"; done

    for i in $VIGRID_OPENVPN_CLIENTS
    do
      Display "    Building '$i' Client certificates:" && /usr/share/easy-rsa/easyrsa --batch build-client-full $i nopass || Error 'action failed,'
      Display "    Generating '$i' OpenVPN TLS-Auth key..." && openvpn --genkey secret pki/$i-ta.key || Error 'action failed,'
    done
    Display "  Creating OpenVPN CyberRange.conf server file"

    Display -h -n "    IP addressing plans:
      Nsuperadmin0   = $NET_Nsuperadmin0
"
    [ $VIGRID_NETWORK -eq 3 ] && Display -h -n "      Nblue_admin0   = $NET_Nblue_admin0
      Nred_admin0    = $NET_Nred_admin0
"
    Display -h "      Nblue_exposed0 = $NET_Nblue_exposed0
      Nblue_users0   = $NET_Nblue_users0
      Nred_exposed0  = $NET_Nred_exposed0
      Nred_users0    = $NET_Nred_users0
"

    Display -h "      VIGRIDteleport:"
    TEXT=""
    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Oblue_servers${i}}"
      TEXT="$TEXT
        VIGRIDblue_servers$i = $LINE"
    done
    Display -h "$TEXT"

    TEXT=""
    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Ored_servers${i}}"
      TEXT="$TEXT
        VIGRIDred_servers$i = $LINE"
    done
    Display -h "$TEXT"

    TEXT=""
    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Oblue_users${i}}"
      TEXT="$TEXT
        VIGRIDblue_users$i   = $LINE"
    done    
    Display -h "$TEXT"

    TEXT=""
    for i in `seq 1 8`
    do
      eval "LINE=\${NET_Ored_users${i}}"
      TEXT="$TEXT
        VIGRIDred_users$i    = $LINE"
    done
    Display -h "$TEXT"

    echo "#
# Vigrid CyberRange OpenVPN server configuration file
#

# Network
local 127.0.0.1
port 1194
proto tcp4-server
dev tun

# Keys
ca /etc/openvpn/certs/pki/ca.crt
cert /etc/openvpn//certs/pki/issued/CyberRange.crt
key /etc/openvpn/certs/pki/private/CyberRange.key
tls-auth /etc/openvpn/certs/pki/VIGRIDclient-ta.key 0

# Diffie hellman parameters.
dh /etc/openvpn/certs/pki/dh.pem

# OpenVPN privileges
user gns3
group gns3

# Tunnel
topology net30
server 10.8.0.0 255.255.224.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
keepalive 10 120

cipher AES-256-CBC
cipher AES-128-CBC
auth SHA512
auth SHA256
key-direction 0

# Max number of client at a time: 8 Blue, 8 red, both servers or users = 32, + 250 single users.
# Think about checking if GNS3 master able to handle that much. Ciphering consumes CPU...
max-clients 300

# Users authentication
script-security 2
auth-user-pass-verify /home/gns3/vigrid/bin/openvpn-auth via-file

# Username to CN
username-as-common-name

# Same OpenVPN client multiple times (only for single users, not VIGRIDteleport LANtoLAN)
duplicate-cn

# Keep same IP if possible
persist-remote-ip

# Vigrid clients (VIGRIDteleport)
client-config-dir VIGRIDteleport

status /var/log/openvpn/openvpn-status.log

# Set the appropriate level of log file verbosity.
# 0 is silent, except for fatal errors
# 4 is reasonable for general usage
# 5 and 6 can help to debug connection problems
# 9 is extremely verbose
verb 3

# Dialin Admins
server $OVPN_Nsuperadmin_users0

; Nsuperadmin0
push \"route $OVPN_Nsuperadmin0\"
">/etc/openvpn/CyberRange.conf || Error 'Failed to create CyberRange.conf,'

    if [ $VIGRID_NETWORK -eq 3 ]
    then
      echo "
; Nblue_admin0
push \"route $OVPN_Nblue_admin0\"
; Nred_admin0
push \"route $OVPN_Nred_admin0\"">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (BRadmin),'
    fi

    echo "; Nblue_exposed0
push \"route $OVPN_Nblue_exposed0\"
; Nblue_users0 
push \"route $OVPN_Nblue_users0\"
; Nred_exposed0
push \"route $OVPN_Nred_exposed0\"
; Nred_users0
push \"route $OVPN_Nred_users0\"">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange (BRexposed+users).conf,'

    # VIGRIDteleport
    echo "
; VIGRIDteleport (BLUEservers)">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (Bservers),'
    for i in `seq 1 8`
    do
      eval "LINE=\${OVPN_Oblue_servers${i}}"
      echo "; VIGRIDblue_servers$i
push \"route $LINE\"">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (Bservers#),'
    done

    echo "
; VIGRIDteleport (REDservers)">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (Rservers),'
    for i in `seq 1 8`
    do
      eval "LINE=\${OVPN_Ored_servers${i}}"

      echo "; VIGRIDred_servers$i
push \"route $LINE\"">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (Rservers#),'
    done

    echo "
; VIGRIDteleport (BLUEusers)">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (OVPN_Busers),'
    for i in `seq 1 8`
    do
      eval "LINE=\${OVPN_Oblue_users${i}}"

      echo "; VIGRIDblue_users$i
push \"route $LINE\"">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (OVPN_Busers#),'
    done    

    echo "
; VIGRIDteleport (REDusers)">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (OVPN_Rusers),'
    for i in `seq 1 8`
    do
      eval "LINE=\${OVPN_Ored_users${i}}"

      echo "; VIGRIDred_users$i
push \"route $LINE\"">>/etc/openvpn/CyberRange.conf || Error 'Failed to update CyberRange.conf (OVPN_Rusers#),'
    done    


    # Display -h "Creating /etc/openvpn/vigrid-openvpn-auth script..."
    # echo "#!/bin/sh

# Script to call Vigrid OpenVPN Authentication script

# /home/gns3/vigrid/bin/openvpn-auth $*
# " >/etc/openvpn/vigrid-openvpn-auth || Error 'Cant create /etc/openvpn/vigrid-openvpn-auth,'
    # chmod 755 /etc/openvpn/vigrid-openvpn-auth || Error 'Cant chmod 755 /etc/openvpn/vigrid-openvpn-auth,'
  
    Display "Now creating OpenVPN client configuration file (with $HOST_IP:443 as server)..."
    echo "#
# Vigrid OpenVPN client configuration file
#

client
remote $HOST_IP 443
dev tun
proto tcp

resolv-retry infinite
nobind

persist-key
persist-tun

cipher AES-256-CBC
cipher AES-128-CBC
auth SHA512
auth SHA256

key-direction 1
remote-cert-tls server

# Authenticate user (plus password in TLSAUTH)
auth-user-pass

# Set log file verbosity.
verb 3
" >/etc/openvpn/client/conf_VIGRIDclient

    cat /etc/openvpn/client/conf_VIGRIDclient >/etc/openvpn/client/ovpn_VIGRIDclient

    echo "# Certificates
<ca>
`cat /etc/openvpn/certs/pki/ca.crt`
</ca>
<cert>
`cat /etc/openvpn/certs/pki/issued/VIGRIDclient.crt`
</cert>
<key>
`cat /etc/openvpn/certs/pki/private/VIGRIDclient.key`
</key>
<tls-auth>
`cat /etc/openvpn/certs/pki/VIGRIDclient-ta.key`
</tls-auth>
" >>/etc/openvpn/client/ovpn_VIGRIDclient
    Display "  Vigrid OpenVPN Client configuration file is /etc/openvpn/client/ovpn_VIGRIDclient.

  Disabling OpenVPN client..."
    systemctl disable openvpn-client@service || Error 'disabling failed,'

    Display -h "  Creating OpenVPN VIGRIDteleport clients directory"
    mkdir /etc/openvpn/VIGRIDteleport || Error 'creation failed,'

    for i in `seq 1 8`
    do
      # VIGRIDblue_servers
      eval "LINE=\${OVPN_Oblue_servers${i}}"
      VIGRIDclient="VIGRIDblue_servers$i"
      VIGRID_DHCP_IP="172.29.9.254"
      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      echo "# VIGRIDteleport: $i
iroute $NET_BASE $NET_MASK
push \"ifconfig-pool $NET_BASE $NET_BROADCAST $NET_MASK\"
push \"setenv-safe VIGRID_DHCP_IP $VIGRID_DHCP_IP\"
" >/etc/openvpn/VIGRIDteleport/$VIGRIDclient

      # VIGRIDblue_users
      eval "LINE=\${OVPN_Oblue_users${i}}"
      VIGRIDclient="VIGRIDblue_users$i"
      VIGRID_DHCP_IP="172.29.9.254"
      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      echo "# VIGRIDteleport: $i
iroute $NET_BASE $NET_MASK
push \"ifconfig-pool $NET_BASE $NET_BROADCAST $NET_MASK\"
push \"setenv-safe VIGRID_DHCP_IP $VIGRID_DHCP_IP\"
" >/etc/openvpn/VIGRIDteleport/$VIGRIDclient

      # VIGRIDred_servers
      eval "LINE=\${OVPN_Ored_servers${i}}"
      VIGRIDclient="VIGRIDred_servers$i"
      VIGRID_DHCP_IP="172.29.13.254"
      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      echo "# VIGRIDteleport: $i
iroute $NET_BASE $NET_MASK
push \"ifconfig-pool $NET_BASE $NET_BROADCAST $NET_MASK\"
push \"setenv-safe VIGRID_DHCP_IP $VIGRID_DHCP_IP\"
" >/etc/openvpn/VIGRIDteleport/$VIGRIDclient

      # VIGRIDred_users
      eval "LINE=\${OVPN_Ored_users${i}}"
      VIGRIDclient="VIGRIDred_users$i"
      VIGRID_DHCP_IP="172.29.13.254"
      NET_BASE=`echo $LINE| awk 'BEGIN { FS="/";} {print $1;}'`
      NET_MASK=`echo $LINE| awk 'BEGIN { FS="/";} {print $2;}'`
      NET_BROADCAST=`sipcalc $NET_BASE $NET_MASK|grep "^Broadcast"|awk '{print $NF;}'`
      echo "# VIGRIDteleport: $i
iroute $NET_BASE $NET_MASK
push \"ifconfig-pool $NET_BASE $NET_BROADCAST $NET_MASK\"
push \"setenv-safe VIGRID_DHCP_IP $VIGRID_DHCP_IP\"
" >/etc/openvpn/VIGRIDteleport/$VIGRIDclient
    done

    Display "Removing Apache2 forced install..." && apt purge -y apache2*

    LIST="/lib/systemd/system/openvpn@.service /lib/systemd/system/openvpn-server@.service /lib/systemd/system/openvpn.service"
    for i in $LIST
    do
      Display -h "  Removing ProtectHome from $i..."
      cat $i 2>/dev/null |grep -v "^ProtectHome" >/tmp/tmp$$
      cat /tmp/tmp$$ 2>/dev/null >$i
      rm /tmp/tmp$$ >/dev/null 2>/dev/null
      
      Display -h "  Setting LimitNPROC=infinite in $i..."
      cat $i 2>/dev/null | sed 's/^LimitNPROC=.*/LimitNPROC=infinite/i' >/tmp/tmp$$
      cat /tmp/tmp$$ 2>/dev/null >$i
      rm /tmp/tmp$$ >/dev/null 2>/dev/null
    done
    systemctl daemon-reload

    Display -h "  Finally enabling OpenVPN server" && systemctl enable openvpn || Error 'Enabling failed,'
  else
    Display -h "  Configuring SSLh (with current IP=$HOST_IP)..."
    chown -R sslh /var/run/sslh
    echo "
DAEMON_OPTS=\"--user=sslh --listen=$HOST_IP:443 --ssh=localhost:22 --openvpn=127.0.0.1:1194 --tls=127.0.0.1:443 --pidfile=/var/run/sslh/sslh.pid\"" >>/etc/default/sslh
  fi

  Display -h "Enabling & starting SSLh..."
  systemctl enable sslh
  service sslh start

  Display "Installing MariaDB server..." && apt install -y mariadb-server php-mysql || Error 'Install failed,'

  Display "  Creating 'Vigrid' database..."
  echo "CREATE DATABASE Vigrid;" | mysql
  Display -h "  Adding 'vigrid' account for MariaDB Vigrid database..."
  # echo "GRANT CREATE ON *.* to 'vigrid'@'%' identified by '$VIGRID_MYSQL_PASS';" | mysql
  echo "GRANT ALL ON Vigrid.* to 'vigrid'@'%' identified by '$VIGRID_MYSQL_PASS';" | mysql
  # echo "GRANT ALL ON *.* to 'vigrid'@'%' identified by '$VIGRID_MYSQL_PASS';" | mysql

  Display "I will now install Postfix so I can send emails to GNS clone owners."

  Display -h "Please select the best configuration for your server once prompted"
  Display -h "Post will be needed to send email from Vigrid cloning service to 'any' Internet email"

  Display -h -n "Installing postfix & mailutils..." && apt install -y postfix mailutils || Error 'Install failed,'
fi

Display "  Linking /etc/sudoers.d/vigrid to /home/gns3/vigrid/sudoers & set root ownership..."
ln -s /home/gns3/vigrid/etc/sudoers /etc/sudoers.d/vigrid || Error 'Linking failed,'
chown root:root /home/gns3/vigrid/etc/sudoers
Display -h "Upon Vigrid sudoers file update, the starting script will automatically reset it to root user."

# Master or Slave, Cyber Range design -> Firewall
if [ $VIGRID_NETWORK -eq 2 -o $VIGRID_NETWORK -eq 3 ]
then
  Display "Adding IPtables..." && apt install -y iptables-persistent || Error 'Install failed,'
  mkdir -p /etc/iptables >/dev/null 2>/dev/null
  
  Display "Adding Vigrid Firewall rules..."
  
  # FW rules
  if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ] # Vigrid slave, different rules since not router/OpenVPN
  then
    echo "#
# Vigrid Slave Firewall rules
#
# A slave does not route, even if multi homed between Admin & Internet
# FILTER
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:DOCKER - [0:0]
:DOCKER-ISOLATION-STAGE-1 - [0:0]
:DOCKER-ISOLATION-STAGE-2 - [0:0]
:DOCKER-USER - [0:0]
:LOG_ACCEPT - [0:0]
:LOG_DROP - [0:0]

# On Slaves, all Network interfaces are opened
-A INPUT -i lo             -j LOG_ACCEPT
-A INPUT -i Nsuperadmin0   -j LOG_ACCEPT
-A INPUT -i Nblue_admin0   -j LOG_ACCEPT
-A INPUT -i Nred_admin0    -j LOG_ACCEPT
-A INPUT -i Nblue_exposed0 -j LOG_ACCEPT
-A INPUT -i Nred_exposed0  -j LOG_ACCEPT

# NAT Cloud
-A INPUT -i virbr0 -p icmp -j LOG_ACCEPT
-A INPUT -i virbr0 -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 53 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 67 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 68 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT

# If Ninternet0 is plugged, direct SSH to Slave is possible
-A INPUT -i Ninternet0 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
# as well as pinging it
-A INPUT -i Ninternet0 -p icmp -j LOG_ACCEPT

# Responses
-A INPUT -i Ninternet0 -m conntrack --ctstate RELATED,ESTABLISHED -j LOG_ACCEPT

# Default policy : Drop & log
-A INPUT -j LOG_DROP

# Docker stuff
-A FORWARD -j DOCKER-USER
-A FORWARD -j DOCKER-ISOLATION-STAGE-1
-A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j LOG_ACCEPT
-A FORWARD -o docker0 -j DOCKER
-A FORWARD -i docker0 ! -o docker0 -j LOG_ACCEPT
-A FORWARD -i docker0 -o docker0   -j LOG_ACCEPT
# NAT Cloud towards Ninternet0 only
-A FORWARD -i virbr0 -o Ninternet0 -j LOG_ACCEPT
-A FORWARD -i virbr0 ! -o Ninternet0 -j LOG_DROP

# Cyber range Policy
-A FORWARD -i Ninternet0     -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nred_exposed0  -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nblue_exposed0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nblue_admin0   -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nred_admin0    -o Nsuperadmin0 -j LOG_DROP

-A FORWARD -i Ninternet0     -o Nblue_admin0 -j LOG_DROP
-A FORWARD -i Nblue_exposed0 -o Nblue_admin0 -j LOG_DROP
-A FORWARD -i Nred_exposed0  -o Nblue_admin0 -j LOG_DROP

-A FORWARD -i Ninternet0     -o Nred_admin0 -j LOG_DROP
-A FORWARD -i Nblue_exposed0 -o Nred_admin0  -j LOG_DROP
-A FORWARD -i Nred_exposed0  -o Nred_admin0  -j LOG_DROP

-A FORWARD -j LOG_ACCEPT

# On Slaves, all Network interfaces are opened
-A OUTPUT -o lo             -j LOG_ACCEPT

-A OUTPUT -o Ninternet0     -j LOG_ACCEPT

-A OUTPUT -o Nsuperadmin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -s $NET_Nsuperadmin0 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -j LOG_DROP

-A OUTPUT -o Nblue_exposed0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nblue_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nblue_exposed0 -s $NET_Nblue_exposed0 -j LOG_ACCEPT
-A OUTPUT -o Nblue_exposed0 -j LOG_DROP

-A OUTPUT -o Nred_exposed0 -d $NET_Nsuperadmin0        -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d $NET_Nsuperadmin_users0  -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d $NET_Nred_admin0         -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d $NET_Nblue_admin0        -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nred_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nred_exposed0 -s $NET_Nred_exposed0 -j LOG_ACCEPT
-A OUTPUT -o Nred_exposed0 -j LOG_DROP

-A OUTPUT -o Nblue_users0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nblue_users0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nblue_users0 -s $NET_Nblue_users0 -j LOG_ACCEPT
-A OUTPUT -o Nblue_users0 -j LOG_DROP

-A OUTPUT -o Nred_users0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nred_users0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nred_users0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nred_users0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nred_users0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nred_users0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nred_users0 -s $NET_Nred_users0 -j LOG_ACCEPT
-A OUTPUT -o Nred_users0 -j LOG_DROP

-A OUTPUT -o Nred_admin0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d $NET_Nblue_exposed0     -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nred_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nred_admin0 -s $NET_Nred_admin0 -j LOG_ACCEPT
-A OUTPUT -o Nred_admin0 -j LOG_DROP

-A OUTPUT -o Nblue_admin0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d $NET_Nred_exposed0      -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nblue_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nblue_admin0 -s $NET_Nblue_admin0 -j LOG_ACCEPT
-A OUTPUT -o Nblue_admin0 -j LOG_DROP

# Default policy
-A OUTPUT -j LOG_DROP

# Docker stuff
-A DOCKER-ISOLATION-STAGE-1 -i docker0 ! -o docker0 -j DOCKER-ISOLATION-STAGE-2
-A DOCKER-ISOLATION-STAGE-1 -j RETURN
-A DOCKER-ISOLATION-STAGE-2 -o docker0 -j DROP
-A DOCKER-ISOLATION-STAGE-2 -j RETURN
-A DOCKER-USER -j RETURN

# log & drop
-A LOG_DROP -m limit --limit 30/min -j LOG --log-prefix \"IPtables DROP: \" --log-level 7
-A LOG_DROP -j DROP
# log & accept
#-A LOG_ACCEPT -m limit --limit 30/min -j LOG --log-prefix \"IPtables ACCEPT: \" --log-level 7
-A LOG_ACCEPT -j ACCEPT

COMMIT
# NAT
*nat
:PREROUTING ACCEPT [3:180]
:INPUT ACCEPT [3:180]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
:DOCKER - [0:0]
# Docker stuff
-A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
-A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
# NAT Cloud
-A POSTROUTING -s 192.168.122.0/24 -d 224.0.0.0/24 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 -d 255.255.255.255/32 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
-A POSTROUTING -s 192.168.122.0/24 -d 224.0.0.0/24 -j RETURN
-A DOCKER -i docker0 -j RETURN
COMMIT
# MANGLE
*mangle
:PREROUTING ACCEPT [7012915:35979202658]
:INPUT ACCEPT [6817123:35399584140]
:FORWARD ACCEPT [195801:579621588]
:OUTPUT ACCEPT [4464499:58782466335]
:POSTROUTING ACCEPT [4660300:59362087923]
COMMIT" >/etc/iptables/rules.vigrid
  else # Master FW rules, acting as Router, OpenVPN gateway...
    echo "#
# Vigrid Master Firewall rules
#
# MANGLE
*mangle
:PREROUTING ACCEPT [398669:81946452]
:INPUT ACCEPT [389581:81245374]
:FORWARD ACCEPT [4471:471508]
:OUTPUT ACCEPT [385253:836508043]
:POSTROUTING ACCEPT [386992:836802374]
-A POSTROUTING -o virbr0 -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
COMMIT

# FILTER
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [28002:3907426]
:DOCKER - [0:0]
:DOCKER-ISOLATION-STAGE-1 - [0:0]
:DOCKER-ISOLATION-STAGE-2 - [0:0]
:DOCKER-USER - [0:0]
:LOG_ACCEPT - [0:0]
:LOG_DROP - [0:0]

-A INPUT -i virbr0 -p icmp -j LOG_ACCEPT
-A INPUT -i virbr0 -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 53 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 67 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 68 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT

-A INPUT -i lo -j LOG_ACCEPT

# Temporary for Vigrid install, should be removed later
-A INPUT -i Ninternet0 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
# Vigrid HTTPS/SSH/OpenVPN
-A INPUT -i Ninternet0 -p tcp -m tcp --dport 443 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i Ninternet0 -p icmp -j LOG_ACCEPT
#
-A INPUT -i Ninternet0 -m conntrack --ctstate RELATED,ESTABLISHED -j LOG_ACCEPT
-A INPUT -i Ninternet0 -j LOG_DROP
#
-A INPUT -i Nsuperadmin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A INPUT -i Nsuperadmin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A INPUT -i Nsuperadmin0 -s $NET_Nsuperadmin0       -j LOG_ACCEPT
-A INPUT -i Nsuperadmin0 -s $NET_Nsuperadmin_users0 -j LOG_ACCEPT
-A INPUT -i Nsuperadmin0 -j LOG_DROP

-A INPUT -i Nblue_exposed0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A INPUT -i Nblue_exposed0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A INPUT -i Nblue_exposed0 -d $NET_Nred_admin0        -j LOG_DROP
-A INPUT -i Nblue_exposed0 -d $NET_Nblue_admin0       -j LOG_DROP
-A INPUT -i Nblue_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A INPUT -i Nblue_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A INPUT -i Nblue_exposed0 -s $NET_Nblue_exposed0 -j LOG_ACCEPT
-A INPUT -i Nblue_exposed0 -j LOG_DROP

-A INPUT -i Nred_exposed0 -d $NET_Nsuperadmin0        -j LOG_DROP
-A INPUT -i Nred_exposed0 -d $NET_Nsuperadmin_users0  -j LOG_DROP
-A INPUT -i Nred_exposed0 -d $NET_Nred_admin0         -j LOG_DROP
-A INPUT -i Nred_exposed0 -d $NET_Nblue_admin0        -j LOG_DROP
-A INPUT -i Nred_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A INPUT -i Nred_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A INPUT -i Nred_exposed0 -s $NET_Nred_exposed0 -j LOG_ACCEPT
-A INPUT -i Nred_exposed0 -j LOG_DROP

-A INPUT -i Nblue_users0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A INPUT -i Nblue_users0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A INPUT -i Nblue_users0 -d $NET_Nred_admin0        -j LOG_DROP
-A INPUT -i Nblue_users0 -d $NET_Nblue_admin0       -j LOG_DROP
-A INPUT -i Nblue_users0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A INPUT -i Nblue_users0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A INPUT -i Nblue_users0 -s $NET_Nblue_users0 -j LOG_ACCEPT
-A INPUT -i Nblue_users0 -j LOG_DROP

-A INPUT -i Nred_users0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A INPUT -i Nred_users0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A INPUT -i Nred_users0 -d $NET_Nred_admin0        -j LOG_DROP
-A INPUT -i Nred_users0 -d $NET_Nblue_admin0       -j LOG_DROP
-A INPUT -i Nred_users0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A INPUT -i Nred_users0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A INPUT -i Nred_users0 -s $NET_Nred_users0 -j LOG_ACCEPT
-A INPUT -i Nred_users0 -j LOG_DROP

-A INPUT -i Nred_admin0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A INPUT -i Nred_admin0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A INPUT -i Nred_admin0 -d $NET_Nblue_admin0       -j LOG_DROP
-A INPUT -i Nred_admin0 -d $NET_Nblue_exposed0     -j LOG_DROP
-A INPUT -i Nred_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A INPUT -i Nred_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A INPUT -i Nred_admin0 -s $NET_Nred_admin0 -j LOG_ACCEPT
-A INPUT -i Nred_admin0 -j LOG_DROP

-A INPUT -i Nblue_admin0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A INPUT -i Nblue_admin0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A INPUT -i Nblue_admin0 -d $NET_Nred_admin0        -j LOG_DROP
-A INPUT -i Nblue_admin0 -d $NET_Nred_exposed0      -j LOG_DROP
-A INPUT -i Nblue_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A INPUT -i Nblue_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A INPUT -i Nblue_admin0 -s $NET_Nblue_admin0 -j LOG_ACCEPT
-A INPUT -i Nblue_admin0 -j LOG_DROP

-A INPUT -i tun0 -s $NET_Nsuperadmin_users0         -j LOG_ACCEPT
-A INPUT -i tun0 -s $NET_VIGRIDteleport_BLUEusers   -j LOG_ACCEPT
-A INPUT -i tun0 -s $NET_VIGRIDteleport_BLUEservers -j LOG_ACCEPT
-A INPUT -i tun0 -s $NET_VIGRIDteleport_REDusers    -j LOG_ACCEPT
-A INPUT -i tun0 -s $NET_VIGRIDteleport_REDservers  -j LOG_ACCEPT

# Policy
-A INPUT -j LOG_DROP

-A FORWARD -i virbr0 -o Ninternet0 -j LOG_ACCEPT

# From Nred_exposed0
-A FORWARD -i Nred_exposed0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nred_exposed0 -o Nblue_admin0 -j LOG_DROP
-A FORWARD -i Nred_exposed0 -o Nred_admin0  -j LOG_DROP
-A FORWARD -i Nred_exposed0 -o Nblue_exposed0 -s $NET_Nred_exposed0 -d $NET_Nblue_exposed0 -j LOG_ACCEPT

# From Nblue_exposed0
-A FORWARD -i Nblue_exposed0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nblue_exposed0 -o Nblue_admin0 -j LOG_DROP
-A FORWARD -i Nblue_exposed0 -o Nred_admin0  -j LOG_DROP
-A FORWARD -i Nblue_exposed0 -o Nred_exposed0 -s $NET_Nblue_exposed0 -d $NET_Nred_exposed0 -j LOG_ACCEPT

# From Nred_users0
-A FORWARD -i Nred_users0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nred_users0 -o Nblue_admin0 -j LOG_DROP
-A FORWARD -i Nred_users0 -o Nred_admin0  -j LOG_DROP
-A FORWARD -i Nred_users0 -o Nblue_users0 -s $NET_Nred_users0 -d $NET_Nblue_users0 -j LOG_ACCEPT

# From Nblue_users0
-A FORWARD -i Nblue_users0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -i Nblue_users0 -o Nblue_admin0 -j LOG_DROP
-A FORWARD -i Nblue_users0 -o Nred_admin0  -j LOG_DROP
-A FORWARD -i Nblue_users0 -o Nred_users0 -s $NET_Nblue_users0 -d $NET_Nred_users0 -j LOG_ACCEPT

# From Nred_admin0
-A FORWARD -i Nred_admin0 -o Nsuperadmin0   -j LOG_DROP
-A FORWARD -i Nred_admin0 -o Nblue_admin0   -j LOG_DROP
-A FORWARD -i Nred_admin0 -o Nblue_exposed0 -j LOG_DROP

# From Nblue_admin0
-A FORWARD -i Nblue_admin0 -o Nsuperadmin0  -j LOG_DROP
-A FORWARD -i Nblue_admin0 -o Nred_admin0   -j LOG_DROP
-A FORWARD -i Nblue_admin0 -o Nred_exposed0 -j LOG_DROP

# From OpenVPN to OpenVPN
-A FORWARD -i tun0 -o tun0  -s $NET_VIGRIDteleport_BLUEservers -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A FORWARD -i tun0 -o tun0  -s $NET_VIGRIDteleport_BLUEusers   -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A FORWARD -i tun0 -o tun0  -s $NET_VIGRIDteleport_REDservers  -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A FORWARD -i tun0 -o tun0  -s $NET_VIGRIDteleport_REDusers    -d $NET_Nsuperadmin_users0 -j LOG_DROP

# From OpenVPN to NIC
-A FORWARD -s $NET_VIGRIDteleport_BLUEservers -i tun0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -s $NET_VIGRIDteleport_BLUEusers   -i tun0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -s $NET_VIGRIDteleport_BLUEservers -i tun0 -o Nred_admin0  -j LOG_DROP
-A FORWARD -s $NET_VIGRIDteleport_BLUEusers   -i tun0 -o Nred_admin0  -j LOG_DROP

-A FORWARD -s $NET_VIGRIDteleport_REDservers  -i tun0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -s $NET_VIGRIDteleport_REDusers    -i tun0 -o Nsuperadmin0 -j LOG_DROP
-A FORWARD -s $NET_VIGRIDteleport_REDservers  -i tun0 -o Nblue_admin0 -j LOG_DROP
-A FORWARD -s $NET_VIGRIDteleport_REDusers    -i tun0 -o Nblue_admin0 -j LOG_DROP

# From NIC to OpenVPN
-A FORWARD -d $NET_VIGRIDteleport_BLUEservers -i Nred_admin0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_VIGRIDteleport_BLUEusers   -i Nred_admin0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_Nsuperadmin_users0         -i Nred_admin0 -o tun0 -j LOG_DROP

-A FORWARD -d $NET_VIGRIDteleport_REDservers -i Nblue_admin0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_VIGRIDteleport_REDusers   -i Nblue_admin0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_Nsuperadmin_users0        -i Nblue_admin0 -o tun0 -j LOG_DROP

-A FORWARD -d $NET_VIGRIDteleport_BLUEservers -i Nred_exposed0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_VIGRIDteleport_BLUEusers   -i Nred_exposed0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_Nsuperadmin_users0         -i Nred_exposed0 -o tun0 -j LOG_DROP

-A FORWARD -d $NET_VIGRIDteleport_REDservers -i Nblue_exposed0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_VIGRIDteleport_REDusers   -i Nblue_exposed0 -o tun0 -j LOG_DROP
-A FORWARD -d $NET_Nsuperadmin_users0        -i Nblue_exposed0 -o tun0 -j LOG_DROP

# Policy
-A FORWARD -j LOG_ACCEPT

# Outputs
-A OUTPUT -o lo  -j LOG_ACCEPT

-A OUTPUT -o Ninternet0 -j LOG_ACCEPT

-A OUTPUT -o Nsuperadmin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -d $NET_Nsuperadmin0 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -d $NET_Nsuperadmin_users0 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -s $NET_Nsuperadmin0 -j LOG_ACCEPT
-A OUTPUT -o Nsuperadmin0 -j LOG_DROP

-A OUTPUT -o Nblue_exposed0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nblue_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nblue_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nblue_exposed0 -s $NET_Nblue_exposed0 -j LOG_ACCEPT
-A OUTPUT -o Nblue_exposed0 -j LOG_DROP

-A OUTPUT -o Nred_exposed0 -d $NET_Nsuperadmin0        -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d $NET_Nsuperadmin_users0  -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d $NET_Nred_admin0         -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d $NET_Nblue_admin0        -j LOG_DROP
-A OUTPUT -o Nred_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nred_exposed0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nred_exposed0 -s $NET_Nred_exposed0 -j LOG_ACCEPT
-A OUTPUT -o Nred_exposed0 -j LOG_DROP

-A OUTPUT -o Nblue_users0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nblue_users0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nblue_users0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nblue_users0 -s $NET_Nblue_users0 -j LOG_ACCEPT
-A OUTPUT -o Nblue_users0 -j LOG_DROP

-A OUTPUT -o Nred_users0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nred_users0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nred_users0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nred_users0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nred_users0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nred_users0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nred_users0 -s $NET_Nred_users0 -j LOG_ACCEPT
-A OUTPUT -o Nred_users0 -j LOG_DROP

-A OUTPUT -o Nred_admin0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d $NET_Nblue_admin0       -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d $NET_Nblue_exposed0     -j LOG_DROP
-A OUTPUT -o Nred_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nred_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nred_admin0 -s $NET_Nred_admin0 -j LOG_ACCEPT
-A OUTPUT -o Nred_admin0 -j LOG_DROP

-A OUTPUT -o Nblue_admin0 -d $NET_Nsuperadmin0       -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d $NET_Nsuperadmin_users0 -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d $NET_Nred_admin0        -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d $NET_Nred_exposed0      -j LOG_DROP
-A OUTPUT -o Nblue_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 67 -j LOG_ACCEPT
-A OUTPUT -o Nblue_admin0 -d 255.255.255.255/32 -p udp -m udp --dport 68 -j LOG_ACCEPT
-A OUTPUT -o Nblue_admin0 -s $NET_Nblue_admin0 -j LOG_ACCEPT
-A OUTPUT -o Nblue_admin0 -j LOG_DROP

-A OUTPUT -o tun0 -d $NET_Nsuperadmin_users0         -j LOG_ACCEPT
-A OUTPUT -o tun0 -d $NET_VIGRIDteleport_BLUEusers   -j LOG_ACCEPT
-A OUTPUT -o tun0 -d $NET_VIGRIDteleport_BLUEservers -j LOG_ACCEPT
-A OUTPUT -o tun0 -d $NET_VIGRIDteleport_REDusers    -j LOG_ACCEPT
-A OUTPUT -o tun0 -d $NET_VIGRIDteleport_REDservers  -j LOG_ACCEPT

# Default policy
-A OUTPUT -j LOG_DROP

# log & drop
-A LOG_DROP -m limit --limit 30/min -j LOG --log-prefix \"IPtables DROP: \" --log-level 7
-A LOG_DROP -j DROP
# log & accept
#-A LOG_ACCEPT -m limit --limit 30/min -j LOG --log-prefix \"IPtables ACCEPT: \" --log-level 7
-A LOG_ACCEPT -j ACCEPT

COMMIT
# NAT
*nat
:PREROUTING ACCEPT [211:11626]
:INPUT ACCEPT [6:636]
:OUTPUT ACCEPT [118:7455]
:POSTROUTING ACCEPT [115:7252]
:DOCKER - [0:0]
-A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
-A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
-A POSTROUTING -s 192.168.122.0/24 -d 224.0.0.0/24 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 -d 255.255.255.255/32 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
-A POSTROUTING -s 192.168.122.0/24 -d 224.0.0.0/24 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 -d 255.255.255.255/32 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE
-A POSTROUTING -s 192.168.122.0/24 -d 224.0.0.0/24 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 -d 255.255.255.255/32 -j RETURN
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE

# Cyber Range flows
-A POSTROUTING -s $NET_Nsuperadmin0   -o Nblue_admin0   -j MASQUERADE
-A POSTROUTING -s $NET_Nsuperadmin0   -o Nred_admin0    -j MASQUERADE
-A POSTROUTING -s $NET_Nsuperadmin0   -o Nred_exposed0  -j MASQUERADE
-A POSTROUTING -s $NET_Nsuperadmin0   -o Nblue_exposed0 -j MASQUERADE
-A POSTROUTING -s $NET_Nsuperadmin0   -o Ninternet0     -j MASQUERADE
-A POSTROUTING -s $NET_Nred_admin0    -o Nred_exposed0  -j MASQUERADE
-A POSTROUTING -s $NET_Nred_admin0    -o Ninternet0     -j MASQUERADE
-A POSTROUTING -s $NET_Nblue_admin0   -o Nblue_exposed0 -j MASQUERADE
-A POSTROUTING -s $NET_Nblue_admin0   -o Ninternet0     -j MASQUERADE
-A POSTROUTING -s $NET_Nblue_exposed0 -o Ninternet0     -j MASQUERADE
-A POSTROUTING -s $NET_Nred_exposed0  -o Ninternet0     -j MASQUERADE
-A POSTROUTING -s $NET_Nblue_users0   -o Ninternet0     -j MASQUERADE
-A POSTROUTING -s $NET_Nred_users0    -o Ninternet0     -j MASQUERADE
-A POSTROUTING -o Ninternet0                            -j MASQUERADE

-A DOCKER -i docker0 -j RETURN
COMMIT" >/etc/iptables/rules.vigrid
  fi

  FW_RULES_SIZE=`cat /etc/iptables/rules.vigrid  2>/dev/null | wc -l`
  [ $FW_RULES_SIZE -lt 30 ] && Error 'Firewall rules are less than 30 lines, that is not normal,'

  # Tiny Cyber range, 
  if [ $VIGRID_NETWORK -eq 2 ]
  then
    Display -h "  Updating FW rules for a Tiny CyberRange design"

    FILTER_NAME="Nblue_admin0|Nred_admin0"
    FILTER_IP=`echo "$NET_Nblue_admin0|$NET_Nred_admin0" | awk -F '/' -v OFS='\\\/' '$1=$1'`
    FILTER="($FILTER_NAME|$FILTER_IP)"

    cat /etc/iptables/rules.vigrid | egrep -v "$FILTER" >/etc/iptables/rules.vigrid.new

    FW_RULES_SIZE=`cat /etc/iptables/rules.vigrid.new | wc -l`
    [ $FW_RULES_SIZE -lt 30 ] && Error "  After network design filter (\"$FILTER\"), firewall rules are less than 30 lines, that is not normal,"
    
    mv /etc/iptables/rules.vigrid.new /etc/iptables/rules.vigrid
  fi


  if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ] # Vigrid Slave
  then
    if [ $VIGRID_NETWORK -ne 1 ] # Cyber Range design
    then
      Display -h "  Updating FW rules for a Vigrid Slave"
      
      cat /etc/iptables/rules.vigrid | egrep -v 'A INPUT (-d 255.255.255.255\/32|-i Ninternet0 .* --dport 443)' >/etc/iptables/rules.vigrid.new
      mv /etc/iptables/rules.vigrid.new /etc/iptables/rules.vigrid

      cat /etc/iptables/rules.vigrid | egrep -v 'A FORWARD .* (-i tun0|-o Ninternet0)' >/etc/iptables/rules.vigrid.new
      mv /etc/iptables/rules.vigrid.new /etc/iptables/rules.vigrid

      cat /etc/iptables/rules.vigrid | egrep -v 'A POSTROUTING .* -o Ninternet0' >/etc/iptables/rules.vigrid.new
      mv /etc/iptables/rules.vigrid.new /etc/iptables/rules.vigrid
    fi
  fi
  
  FW_RULES_SIZE=`cat /etc/iptables/rules.vigrid | wc -l`
  [ $FW_RULES_SIZE -lt 30 ] && Error '  After Slave filtering, firewall rules are less than 30 lines, that is not normal,'
  
  Display "Activating Firewall rules for backup....should not cut your network session if you dont touch your keyboard..."
  iptables-restore </etc/iptables/rules.vigrid || Error 'Cant restore IPtables rules from rules.vigrid,'
  iptables-save >/etc/iptables/rules.v4 || Error 'Cant save IPtables rules to rules.v4,'

  Display "Reseting loaded Firewall rules (only) to recover current network sessions"
  iptables -F
fi

# Adding Vigrid monitoring
Display "Installing & enabling Vigrid-load monitoring..."
cp /home/gns3/vigrid/etc/init.d/vigrid-load /etc/init.d/
systemctl enable vigrid-load

Display "Final apt autoremove to clean system..." && apt autoremove -y

if [ $VIGRID_TYPE -ge 2 -a $VIGRID_TYPE -le 5 ] # Vigrid with NAS
then
  Display "Reloading autofs..."
  service autofs reload
fi

Display "Sanity enabling & launching all Vigrid services..."
LIST=""
[ $VIGRID_TYPE -ne 1 ] && LIST="autofs"

LIST="$LIST ssh vigrid-load docker gns3"
if [ $VIGRID_TYPE -ge 1 -a $VIGRID_TYPE -le 3 ]
then
  T=`service --status-all|grep "php.*-fpm" | awk '{print $NF;}'`
  LIST="$LIST $T openresty mariadb postfix sslh vigrid-noconsoles vigrid-cloning"
fi

# Cyber Range network design AND master
CND1=0
CND2=0
[ $VIGRID_TYPE -eq 1 -o $VIGRID_TYPE -eq 2 -o $VIGRID_TYPE -eq 3 ] && CND1=1
[ $VIGRID_NETWORK -eq 2 -o $VIGRID_NETWORK -eq 3 ] && CND2=1
[ $CND1 -eq 1 -a $CND2 -eq 1 ] && LIST="$LIST openvpn"

for i in $LIST
do
  Display -h -n "$i..."
  systemctl enable $i >/dev/null 2>/dev/null || Error "Cant enable $i service..."
  if [ $VIGRID_TYPE -ne 6 ]
  then
    systemctl stop $i || Error "Cant stop $i service."
    systemctl start $i || Error "Cant start $i service."
  fi
  Display -h -n "
"
done

Display "CHmoding gns3_controller.conf to allow public read..."
chmod o+r /home/gns3/.config/GNS3/gns3_controller.conf || Error 'chmod failed,'

Display "

Reboot to finalize install once you are ready.

You can connect to 'https://$HOST_IP/manager/vigrid-config.html' (login vigrid/vigrid) to finalize Vigrid configuration.
Connecting to 'https://$HOST_IP/' will give you Vigrid access.
For GNS3 heavy client, connect to HTTPS $HOST_IP, port 443 TCP, same login as above.
Nota: '$HOST_IP' might be different, it is deduced from the current configuration.
      I am sure you will find the good one if I am wrong :-)

Points you might wish to review/consider:
- (!) Setting a root password for MySQL/MariaDB (mysqladmin --user=root password \"newpassword\")
- Add at login '/home/gns3/vigrid/bin:/home/gns3/bin' (**/home/gns3/vigrid/bin must be first**) to your PATH
- Postfix or SMTP relay configuration to be able to send email to clone owners
- PHP FPM pool 'request_terminate_timeout' on big infrastructures
- NGinx configuration for location /v2, timeouts again but for GNS3 this time:  proxy_connect_timeout, proxy_send_timeout, proxy_read_timeout & send_timeout for big appliance images upload

- Network configuration (DHCP client vs static, conflicting DHCP servers, default route, DNS resolving etc)
- NTP synchronization of server(s)"

if [ $VIGRID_NETWORK -eq 2 -o $VIGRID_NETWORK -eq 3 ]
then
  Display -h -n "- /etc/iptables/rules.vigrid allowing 22/TCP (SSH) on Ninternet0, to be removed (SSH listens on 443/TCP with NGinx & OpenVPN"
  Display -h -n "- OpenVPN client connection (use /etc/openvpn/client/ovpn_VIGRIDclient as VIGRIDclient.ovpn)"
fi

[ $VIGRID_TYPE -eq 3 ] && Display -h -n "- Connect to GNS3 Farm/Scalable Master server with GNS3 heavy client and all Scalable (except Farm) slaves"

if [ $VIGRID_TYPE -eq 4 -o $VIGRID_TYPE -eq 5 ]
then
  Display "Vigrid Slave:
- Once Vigrid Slave is rebooted, please run the below command on Vigrid Master:
  /home/gns3/vigrid/bin/vigrid-addslave, and provide the required informations
- Set the password of the gns3 on the slave the same on the master (variable VIGRID_GNS_PASS in vigrid.conf), then launch on Master:
  /home/gns3/vigrid/bin/vigrid-sshcheck -a -s /home/gns3/etc/id_GNS3 -u gns3 -h $HOST"
fi

[ $VIGRID_TYPE -ne 4 -a $VIGRID_TYPE -ne 5 ] && Display -h "
- Recalling GNS3 password: $GNS3_PASS"

Display -h -n "Replacing timesyncd with chrony..."
apt install -y chrony || Error "Chrony add failed,"
apt purge -y systemd-timesyncd || Error "Timesyncd removal failed,"

Display -h "

IMPORTANT: GNS3 is provided with its default configuration. It means there are no appliances or images.
  To learn more about GNS3 usage, appliances, templates... please go to: https://docs.gns3.com/docs/

#############################################################################################
"

Display -h ""

) 2>&1 | tee -a $LOG_FILE
