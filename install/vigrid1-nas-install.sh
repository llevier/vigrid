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
Vigrid extension: NAS install script

This script requires to be launched on the latest Ubuntu LTS version, Internet access (for updates & packages) ready.
Additional partitions/disks should be available. I'll ask you about these to create the NAS storage

Upon any issue, script will pause, proposing to (force) continue, run a sub shell or exit procedure.
Everything will be logged to $LOG_FILE.

Upon any question with default answer, validate the choice.
IMPORTANT: if this server is using DHCP, I'll set the IP address to the one obtained. This IP might change in the future,
especially if you select CyberRange designs.

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
OS_CHK=`echo "$OS_RELEASE" | egrep -i "Ubuntu.*(20|22|24)"|wc -l`
Display -h -n "I see I am launched on a $OS_RELEASE, "
[ $OS_CHK -ge 1 ] && Display -h "perfect to me !"
[ $OS_CHK -ge 1 ] || Display -h "not the one I expected, not sure I will work fine over it."

Display "Now let's check how much RAM server has"
RAM=`free -g|head -2|tail -1|awk '{print $2;}'`
[ $RAM -le 32 ] && Display -h "Server has less than 32GB of physical RAM. With ZFS, it is advise to have much more. I advise 128GB of RAM"

# Server update
Display "Lets update your server first"

apt update -y || Error "Command exited with an error,"
apt full-upgrade -y || Error "Command exited with an error,"
apt autoclean -y || Error "Command exited with an error,"
apt autoremove -y || Error "Command exited with an error,"

# Display "Adding Zrepl repository & tool..."
# curl -fsSL https://zrepl.cschwarz.com/apt/apt-key.asc | tee | gpg --dearmor | apt-key add -
# echo "deb https://zrepl.cschwarz.com/apt/ubuntu `lsb_release -cs` main" | tee /etc/apt/sources.list.d/zrepl.list || Error 'Update failed,'
# apt update -y || Error "Command exited with an error,"
# apt install -y zrepl

Display "Install misc tools..."
apt install -y ipcalc

Display "Removing cloud-init service..."
apt remove -y cloud-init
apt autoremove -y
apt purge -y cloud-init
rm -rf /etc/cloud
find / -name '*cloud-init*'

# Filesystem selection
until false
do
  Display -n "
Please select which filesystem format you wish to use:
  1- ZFS: is very fast, but its design enforces hierarchical snapshots. More suitable for huge cloning, less for trainings
  2- BTRfs: is much better, but 20x slower than ZFS except if you exclusively use SSD drives.
  
Whatever you select, please notice filesystem will be faster if the RAID array is managed by a physical controller.
  
  Your choice -> "
  read ANS
  
  if [ "x$ANS" = "x1" ]
  then
    FS="ZFS"
    FS_ROOT="Vstorage"
    break
  elif  [ "x$ANS" = "x2" ]
  then
    FS="BTRfs"
    FS_ROOT="Vstorage"
    break
  fi
done

# ZFS package install
if [ "x$FS" = "xZFS" ]
then
  Display -h "Now server is updated, let's install ZFS package"
  apt install -y zfsutils-linux || Error "Command exited with an error,"
  [ -x /usr/sbin/zfs ] || Error "Cant find /usr/bin/zfs,"
fi

# Disks identification
Display -n "Identifying available hard drives: "
DSK=`lsblk -S -o NAME | tail -n +2`
Display $DSK

Display -h "  Existing partitions:"
for i in $DSK
do
  Display -h "  - Disk $i:"
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
    Display -h "Please provide a space separated list of FREE partition(s)/full device(s) that will be used for the $FS storage from: $FREE_PARTS"
    read FS_PARTS
    [ "x$FS_PARTS" != "x" ] && break
  done

  NUM_PARTS=`echo $FS_PARTS | wc -w`
  
  if [ $NUM_PARTS -gt 1 ]
  then
    Display -h "You provided multiple partitions. These must be exactly the same to build an array".
    until false
    do
      Display -h "Please select $FS array type:"
      Display -h "  0:  RAID0 -> data spread on all drives. Upon failure of one, you loose everything"
      Display -h "  1:  RAID1 -> Mirror: you loose have the total size of drives, you may loose one at a time"
      [ $NUM_PARTS -ge 3 ] && Display -h "  5:  RAID5 -> Simple parity: you loose 1/3 of total size of drives, you may loose one at a time"
      [ $NUM_PARTS -ge 4 ] && Display -h "  6:  RAID6 -> Double parity: you loose 1/3 of total size of drives, you may loose two at a time"
      
      if [ $NUM_PARTS -ge 5 ]
      then
        [ "x$FS" = "xZFS" ] &&   Display -h "  7:  RAID7 -> Triple parity: you loose 1/3 of total size of drives, you may loose three at a time"
        [ "x$FS" = "xBTRfs" ] && Display -h "  10: RAID10 -> Simple parity per RAID1 group, 1/2 of total size of drives, you may loose one per RAID group at a time"
      fi
      
      read FS_TYPE
      
      [ $FS_TYPE -eq 0 -o $FS_TYPE -eq 1 -o $FS_TYPE -eq 5 -o $FS_TYPE -eq 6 ] && break
      [ "x$FS" = "xZFS" -a $FS_TYPE -eq 7 ] && break
      [ "x$FS" = "xBTRfs" -a $FS_TYPE -eq 10 ] && break
    done
  else
    FS_TYPE=0
  fi

  echo
  echo -n "You requested to build a "
  [ $FS_TYPE -eq 0 ] && Display -h -n "RAID0"
  [ $FS_TYPE -eq 1 ] && Display -h -n "RAID1"
  [ $FS_TYPE -eq 5 ] && Display -h -n "RAID5"
  [ $FS_TYPE -eq 6 ] && Display -h -n "RAID6"

  if [ "x$FS" = "xZFS" ]
  then
    [ $FS_TYPE -eq 7 ] && Display -h -n "RAID7"

    echo " ZFS array using $FS_PARTS."

    COMMAND="zpool create Vstorage"
    [ $FS_TYPE -eq 1 ] && COMMAND="$COMMAND mirror"
    [ $FS_TYPE -eq 5 ] && COMMAND="$COMMAND raidz1"
    [ $FS_TYPE -eq 6 ] && COMMAND="$COMMAND raidz2"
    [ $FS_TYPE -eq 7 ] && COMMAND="$COMMAND raidz3"

    COMMAND="$COMMAND $FS_PARTS"
    echo "Creating pool ($COMMAND)..."
    $COMMAND
    RC=$?
    if [ $RC -ne 0 ]
    then
      until false
      do
        Display -h "ZFS pool creation failed, this might come if the partition/disks were already defined. Do you wish me to try forcing ? [y/N] "
        read ANS
        
        if [ "x$ANS" = "xn" -o "x$ANS" = "xN" ]
        then
          Error "Then you need to take action, I am blocked"
          break
        elif [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
        then
          COMMAND="zpool create -f Vstorage"
          [ $FS_TYPE -eq 1 ] && COMMAND="$COMMAND mirror"
          [ $FS_TYPE -eq 5 ] && COMMAND="$COMMAND raidz1"
          [ $FS_TYPE -eq 6 ] && COMMAND="$COMMAND raidz2"
          [ $FS_TYPE -eq 7 ] && COMMAND="$COMMAND raidz3"
          COMMAND="$COMMAND $FS_PARTS"

          $COMMAND || Error "ZFS pool creation failed,"
          break
        fi
      done      
    fi
    
    Display -h "  Setting ZFS compression..."
    zfs set compression=lz4 $FS_ROOT || Error "Cant set lz4 compression on $FS_ROOT,"

    Display -h "  Setting ZFS sync to standard..."
    zfs set sync=standard $FS_ROOT || Error "Cant set value on $FS_ROOT,"

    Display -h "  Setting ZFS atime to off..."
    zfs set atime=off $FS_ROOT || Error "Cant set value on $FS_ROOT,"

    Display -h "  Setting ZFS xattr to sa..."
    zfs set xattr=sa $FS_ROOT || Error "Cant set value on $FS_ROOT,"

    Display -h "  Setting ZFS redundant_metadata to most..."
    zfs set redundant_metadata=most $FS_ROOT || Error "Cant set value on $FS_ROOT,"

    Display -h "  Disabling ZFS prefetch..."
    echo "options zfs zfs_prefetch_disable=1" >>/etc/modprobe.d/zfs.conf

    until false
    do
      Display -h "Checking Zpool $FS_ROOT exists..."
      zpool status $FS_ROOT >/dev/null 2>/dev/null || Error "Zpool $FS_ROOT does not exist,"
      [ $? -eq 2 -o $? -eq 0 ] && break
    done

    Display -h "ZFS can be much faster reading adding ARC (cache), or much faster writing adding ZIL (logs)."
    Display -h "To be efficient, these *must* be on SSD drives. These can be hardware RAID1 to be even more faster."

    Display -h -n "To add ARC, please provide a partition name, else [RETURN]: "
    read ZFS_ARC
    if [ "x$ZFS_ARC" != "x" ]
    then
      Display -h "Adding $ZFS_ARC as ARC on $FS_ROOT..."
      zpool add $FS_ROOT cache $ZFS_ARC
      RC=$?
      if [ $RC -ne 0 ]
      then
        until false
        do
          Display -h "failed to add $ZFS_ARC, this might come if the partition/disks were already defined. Do you wish me to try forcing ? [y/N] "
          read ANS
          
          if [ "x$ANS" = "xn" -o "x$ANS" = "xN" ]
          then
            Error "Then you need to take action, I am blocked"
            break
          elif [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
          then
            zpool add -f $FS_ROOT cache $ZFS_ARC || Error "failed to add $ZFS_ARC," || Error "ZFS pool update failed,"
            break
          fi
        done      
      fi
      
      Display -h "Tuning L2ARC ZFS values..."
      echo "options zfs l2arc_write_max=1048576000" >>/etc/modprobe.d/zfs.conf
    fi  

    echo -n "To add ZIL, please provide a partition name, else [RETURN]: "
    read ZFS_ZIL
    if [ "x$ZFS_ZIL" != "x" ]
    then
      Display -h "Adding $ZFS_ZIL as ZIL on $FS_ROOT..."
      zpool add $FS_ROOT log $ZFS_ZIL
      RC=$?
      if [ $RC -ne 0 ]
      then
        until false
        do
          Display -h "failed to add $ZFS_ZIL, this might come if the partition/disks were already defined. Do you wish me to try forcing ? [y/N] "
          read ANS
          
          if [ "x$ANS" = "xn" -o "x$ANS" = "xN" ]
          then
            Error "Then you need to take action, I am blocked"
            break
          elif [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
          then
                  zpool add -f $FS_ROOT log $ZFS_ZIL || Error "failed to add $ZFS_ZIL," || Error "ZFS pool update failed,"
            break
          fi
        done      
      fi
      Display -h "With ZIL, checksum can be turned off for $FS_ROOT..."
      zfs set checksum=off Vstorage
    fi  
    
    echo
    echo "Final ZFS pool:"
    zpool status $FS_ROOT
    zfs list $FS_ROOT
    
  elif [ "x$FS" = "xBTRfs" ] ####################### ZFS vs BTRfs #######################
  then
    [ $FS_TYPE -eq 10 ] && Display -h -n "RAID10"

    echo " BTRfs array using $FS_PARTS."

    COMMAND="mkfs.btrfs "
    [ $FS_TYPE -eq 1 ] && COMMAND="$COMMAND -d single -m raid1"
    [ $FS_TYPE -eq 5 ] && COMMAND="$COMMAND -d single -m raid5"
    [ $FS_TYPE -eq 6 ] && COMMAND="$COMMAND -d single -m raid6"
    [ $FS_TYPE -eq 10 ] && COMMAND="$COMMAND -d raid10 -m raid10"

    DEV_FS_PARTS=`echo " "$FS_PARTS | sed 's/ / \/dev\//g'`
    COMMAND="$COMMAND $DEV_FS_PARTS"
    Display -h "Creating BTRfs volume ($COMMAND)..."
    $COMMAND
    RC=$?
    if [ $RC -ne 0 ]
    then
      until false
      do
        Display -h "BTRfs volume creation failed, this might come if the partition/disks were already defined. Do you wish me to try forcing ? [y/N] "
        read ANS
        
        if [ "x$ANS" = "xn" -o "x$ANS" = "xN" ]
        then
          Error "Then you need to take action, I am blocked"
          break
        elif [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
        then
          COMMAND="mkfs.btrfs -f "
          [ $FS_TYPE -eq 1 ] && COMMAND="$COMMAND -d single -m raid1"
          [ $FS_TYPE -eq 5 ] && COMMAND="$COMMAND -d single -m raid5"
          [ $FS_TYPE -eq 6 ] && COMMAND="$COMMAND -d single -m raid6"
          [ $FS_TYPE -eq 10 ] && COMMAND="$COMMAND -d raid10 -m raid10"

          COMMAND="$COMMAND $DEV_FS_PARTS"

          $COMMAND || Error "BTRfs volume creation failed,"
          break
        fi
      done      
    fi

    SSD_OPTS="compress-force=lzo,noatime,autodefrag,space_cache=v2"
    # Is the BTRfs array SSD (mount option) ?
    until false
    do
      Display -h "Is the BTRfs array made exclusive with SSD drives [Y/n] ? "
      read ANS
      
      if [ "x$ANS" = "xn" -o "x$ANS" = "xN" ]
      then
        break
      elif [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
      then
        SSD_OPTS="ssd,ssd_spread,discard,$SSD_OPTS"
        break
      fi
    done

    # BTRfs cache on SSD ?
    # https://wiki.archlinux.org/title/bcache#Setting_up_bcached_btrfs_file_systems_on_an_existing_system
    # https://felixmoessbauer.com/blog-reader/ssd-caching-using-linux.html
    # Only cache READS !!! NEVER writes (SSD loss will kill all array)

    Display -h "  Setting compression..."
    # ZLIB -- slower, higher compression ratio (uses zlib level 3 setting, you can see the zlib level difference between 1 and 6 in zlib sources).
    # LZO -- faster compression and decompression than zlib, worse compression ratio, designed to be fast
    # ZSTD -- (since v4.14) compression comparable to zlib with higher compression/decompression speeds and different ratio levels (details)
    # ZLIB is used on some commercial NAS

    MOUNT_DEV=`echo $DEV_FS_PARTS|sed 's/^.* //'`
    mkdir -p /$FS_ROOT || Error "Cant create mounting point /$FS_ROOT,"
    mount -t btrfs -o $SSD_OPTS $MOUNT_DEV /$FS_ROOT || Error "Cant mount $MOUNT_DEV with options=$SSD_OPTS on /$FS_ROOT,"
    
    until false
    do
      Display -h "Checking BTRfs volume /$FS_ROOT exists..."
      btrfs fi show /$FS_ROOT >/dev/null 2>/dev/null || Error " BTRfs volume /$FS_ROOT does not exist,"
      [ $? -eq 2 -o $? -eq 0 ] && break
    done
    
    Display -h "Finally adding BTRfs volume to /etc/fstab"
    echo "$MOUNT_DEV  /$FS_ROOT btrfs $SSD_OPTS 0 0" >>/etc/fstab || Error "Cant update /etc/fstab,"
  fi # ZFS/BTRfs
    
  Display "Now creating Vigrid datasets:"
  LIST="Backups ISOimages GNS3 GNS3/GNS3repos GNS3/GNS3farm GNS3/GNS3farm/GNS3 GNS3/GNS3farm/GNS3/images GNS3/GNS3farm/GNS3/projects NFS"
  for i in $LIST
  do
    Display -h "$i..."
    if [ "x$FS" = "xZFS" ]
    then
      zfs create -p $FS_ROOT/$i || Error "Cant create $FS_ROOT/$i,"
    elif  [ "x$FS" = "xBTRfs" ]
    then
      btrfs sub create /$FS_ROOT/$i || Error "Cant create /$FS_ROOT/$i,"
    fi
  done

  break  
done
# FS install done

Display "Creating gns3 group..." && groupadd -g 777 -f gns3  2>/dev/null || Error 'Group creation failed,'
Display -h "Creating gns3 user..." && useradd -u 777 -d /Vstorage/GNS3 -m -g gns3 gns3 2>/dev/null || Error 'User creation failed,'

Display "Ok, Vigrid NAS is ready for storing, let's turn it to NFS server now"
apt install -y nfs-kernel-server || Error "Cant install nfs-kernel-server,"

Display "changing default nfs-kernel-server launch values"
cp /etc/default/nfs-kernel-server /etc/default/nfs-kernel-server.org
# cat /etc/default/nfs-kernel-server.org | sed 's/
# RPCNFSDARGS

Display "Creating /etc/exports file with Vigrid GNS3 farm & repo shared"
echo "#
# Vigrid NAS NFS exports file
#
# GLOBAL: GNS3 repositories. Should be shared to Vigrid master GNS3 host only.
/$FS_ROOT/GNS3/GNS3repos                      *.GNS3(rw,nohide,no_root_squash,async,no_subtree_check)

# GNS3 Farm: GNS3 shared + docker per host
/$FS_ROOT/GNS3/GNS3farm/GNS3                  *.GNS3(rw,nohide,secure,no_root_squash,anonuid=777,anongid=777,async,no_subtree_check) 
/$FS_ROOT/GNS3/GNS3farm/GNS3/images           *.GNS3(rw,nohide,secure,no_root_squash,anonuid=777,anongid=777,async,no_subtree_check) 
/$FS_ROOT/GNS3/GNS3farm/GNS3/projects         *.GNS3(rw,nohide,secure,no_root_squash,anonuid=777,anongid=777,async,no_subtree_check) 

# GNS3 independant host using NAS: 
# /$FS_ROOT/NFS/[per_host]/GNS3mount                [per_host].GNS3(rw,nohide,no_root_squash,async,no_subtree_check)
# /$FS_ROOT/NFS/[per_host]/GNS3mount/GNS3           [per_host].GNS3(rw,nohide,no_root_squash,async,no_subtree_check)
# /$FS_ROOT/NFS/[per_host]/GNS3mount/GNS3/projects  [per_host].GNS3(rw,nohide,no_root_squash,async,no_subtree_check)
# /$FS_ROOT/NFS/[per_host]/var-lib-docker           [per_host].GNS3(rw,nohide,no_root_squash,async,no_subtree_check)

" >/etc/exports

until false
do
  Display -n "I could start filling the host file and create the associated datasets & shares. Do you want me to do this ? [y/N] "
  read ANS
  
  if [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
  then
    until false
    do
      Display -h -n "Please enter the IP address of the GNS3 host (standalone, master, slave) or 'q' to finish: "
      read ANS
      
      [ "x$ANS" = "xq" ] && break;
      
      # Check that is an IP address
      CHK=`ipcalc $ANS|grep "^INVALID ADDRESS"|wc -l`
      # CHK=`echo $ANS| egrep '([0-9]{1,3}\.){3}([0-9]{1,3})'`
      # if [ "x$CHK" != "x" ]
      if [ $CHK -eq 0 ]
      then
        GNS_IP=$ANS
        
        CHK=`cat /etc/hosts | grep "^$GNS_IP"`
        if [ "x$CHK" != "x" ]
        then
          Display -h "I am sorry but that IP address is already present in /etc/hosts."
        else
          until false
          do
            Display -h -n "Please enter a *real* hostname (no FQDN/domain name) for IP $GNS_IP for  or 'q' to finish: "
            read GNS_NAME
            
            [ "x$GNS_NAME" = "xq" ] && break
            
            if [ "x$GNS_NAME" != "x" ]
            then
              until false
              do
                Display -n "If the hostname given here does not match the *real* client hostname, NFS mount will fail.
Ok to add $GNS_IP $GNS_NAME to /etc/hosts ? [Y/n] "
                read ANS
                
                if [ "x$ANS" = "xy" -o "x$ANS" = "xY" -o "x$ANS" = "x" ]
                then
                  echo "$GNS_IP $GNS_NAME $GNS_NAME.GNS3" >>/etc/hosts
                  break
                elif [ "x$ANS" = "xn" -o "x$ANS" = "xN" ]
                then
                  break
                fi
              done
              break
            fi
            
          done
        fi
      else
        Display -h "I am sorry, but it does not look like an IP address"
      fi
    done

    Display "Ok, I will now create the associated volumes for these hosts..."
    for i in `cat /etc/hosts|grep "\.GNS3"|awk '{print $NF;}'`
    do
      GNS_NAME=`echo $i| sed 's/\.GNS3//'`
      
      if [ "x$FS" = "xZFS" ] 
      then
        zfs create -p $FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3/projects || Error 'I cant create $FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3/projects,'
        zfs create -p $FS_ROOT/NFS/$GNS_NAME/var-lib-docker || Error 'I cant create $FS_ROOT/NFS/$GNS_NAME/var-lib-docker,'
      elif [ "x$FS" = "xBTRfs" ]
      then
        btrfs sub create /$FS_ROOT/NFS/$GNS_NAME || Error 'I cant create /$FS_ROOT/NFS/$GNS_NAME,'
        btrfs sub create /$FS_ROOT/NFS/$GNS_NAME/GNS3mount || Error 'I cant create /$FS_ROOT/NFS/$GNS_NAME/GNS3mount,'
        btrfs sub create /$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3 || Error 'I cant create /$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3,'
        btrfs sub create /$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3/projects || Error 'I cant create /$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3/projects,'
        btrfs sub create /$FS_ROOT/NFS/$GNS_NAME/var-lib-docker || Error 'I cant create /$FS_ROOT/NFS/$GNS_NAME/var-lib-docker,'
      fi
      
      echo "
# Shares for $GNS_NAME
/$FS_ROOT/NFS/$GNS_NAME/GNS3mount                $i(rw,nohide,secure,no_root_squash,anonuid=777,anongid=777,async,no_subtree_check)
/$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3           $i(rw,nohide,secure,no_root_squash,anonuid=777,anongid=777,async,no_subtree_check)
/$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3/projects  $i(rw,nohide,secure,no_root_squash,anonuid=777,anongid=777,async,no_subtree_check)
/$FS_ROOT/NFS/$GNS_NAME/var-lib-docker           $i(rw,nohide,secure,no_root_squash,anonuid=777,anongid=777,async,no_subtree_check)" >>/etc/exports
    done

    Display "Ok, your /etc/hosts file is now:"
    cat /etc/hosts

    Display -h "When your /etc/exports file contains:"
    cat /etc/exports
    
    Display -h "Changing /Vstorage tree ownership to gns3"
    chown -R gns3:gns3 /Vstorage || Error 'chown gns3:gns3 /Vstorage failed,'

    break
  elif [ "x$ANS" = "xn" -o "x$ANS" = "xN" -o "x$ANS" = "x" ]
  then
    [ "x$FS" = "xZFS" ] && FS_CREATE="
  zfs create -p $FS_ROOT/NFS/[gns3hostname]/GNS3mount/GNS3/projects
  zfs create -p $FS_ROOT/NFS/[gns3hostname]/var-lib-docker"

    [ "x$FS" = "xBTRfs" ] && FS_CREATE="
  btrfs sub create /$FS_ROOT/NFS/[gns3hostname]
  btrfs sub create /$FS_ROOT/NFS/[gns3hostname]/GNS3mount
  btrfs sub create /$FS_ROOT/NFS/[gns3hostname]/GNS3mount/GNS3
  btrfs sub create /$FS_ROOT/NFS/[gns3hostname]/GNS3mount/GNS3/projects
  btrfs sub create /$FS_ROOT/NFS/[gns3hostname]/var-lib-docker"

    Display "
To share resources on a Vigrid NAS, as root:

1- You will have to define into /etc/hosts each of the GNS3 slaves complying with this logic:
[IPaddress]   [gns3hostname].GNS3

2- Then you must create the associated ZFS datasets for these hosts, launching as root per host:
$FS_CREATE

3- Finally, you must now edit /etc/exports to define NFS access rights to you shares, create those missings.
   You can follow examples in /etc/exports file.
   
   For a Farm with a MASTER server + 2 slaves and 2 GNS3 independant servers, the below would do:
   # GNS3 Farm
   /$FS_ROOT/NFS/gns3master/GNS3mount/GNS3 gns3master.GNS3(rw,nohide,crossmnt,no_root_squash,async,no_subtree_check)
   /$FS_ROOT/NFS/gns3slave1/var-lib-docker gns3slave1.GNS3(rw,nohide,crossmnt,no_root_squash,async,no_subtree_check)
   /$FS_ROOT/NFS/gns3slave2/var-lib-docker gns3slave2.GNS3(rw,nohide,crossmnt,no_root_squash,async,no_subtree_check)   
   
   # GNS3 independant hosts: gns3independant1 & gns3independant2
   /$FS_ROOT/NFS/gns3independant1/GNS3mount/GNS3 gns3independant1.GNS3(rw,nohide,crossmnt,no_root_squash,async,no_subtree_check)
   /$FS_ROOT/NFS/gns3independant1/var-lib-docker gns3independant1.GNS3(rw,nohide,crossmnt,no_root_squash,async,no_subtree_check)

   /$FS_ROOT/NFS/gns3independant2/GNS3mount/GNS3 gns3independant2.GNS3(rw,nohide,crossmnt,no_root_squash,async,no_subtree_check)
   /$FS_ROOT/NFS/gns3independant2/var-lib-docker gns3independant2.GNS3(rw,nohide,crossmnt,no_root_squash,async,no_subtree_check)

"
    break
  fi
done

Display "Updating exports..."
exportfs -a || Error "It failed,"

Display -h -n "Detected "
showmount -e `hostname`

Display -h "
Creating /var/log/gns3 directory for logging..."
mkdir -p /var/log/gns3 || Error "mkdir failed,"

Display "Installing Vigrid extension..."
mkdir -p /Vstorage/GNS3/bin 2>/dev/null
Display -h "  /Vstorage/GNS3/bin/vigrid-update"
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

if [ -d /Vstorage/GNS3/vigrid ]
then
  cd /Vstorage/GNS3/vigrid && git config --global --add safe.directory /Vstorage/GNS3/vigrid && git pull || echo Vigrid update failed
else
  cd /Vstorage/GNS3 && git clone https://github.com/llevier/vigrid.git || echo Vigrid update failed
fi

echo "Resetting /Vstorage/GNS3 permissions (need root privilege)..."
chown -R root:root /Vstorage/GNS3  >/dev/null 2>/dev/null

cp /Vstorage/GNS3/vigrid/lib/systemd/system/vigrid-ZFSexportUPD.service /lib/systemd/system/ 2>/dev/null

echo
echo Reloading daemon details
systemctl daemon-reload

echo
echo Restarting services...
LIST="vigrid-ZFSexportUPD vigrid-load"
for i in $LIST
do
  echo "  $i..."
  
  CHK=`systemctl list-unit-files|grep "^$i.service"|awk "{print $2;}"`
  if [ "x$CHK" = "x" ]
  then
    echo "    does not exist in unit files, no action"
  else
    if [ "x$CHK" = "xenabled" ]
    then
      echo "    enabled, restarting it"
      service $i stop
      service $i start
    else
      echo "    disabled, no action"
    fi
  fi
done

echo
echo All done
' >/Vstorage/GNS3/bin/vigrid-update

chmod 755 /Vstorage/GNS3/bin/vigrid-update || Error 'Cant chmod /Vstorage/GNS3/bin/vigrid-update,'
Display -h "  Launching vigrid-update..."
/Vstorage/GNS3/bin/vigrid-update || Error 'vigrid-update failed,'  

Display "Installing PHP CLI & FPM..." && apt install -y php-cli php-fpm php-curl php-mail php-net-smtp || Error 'Install failed,'
Display "Removing Apache2 forced install..." && apt purge -y apache2* || Error 'Uninstall failed,'
  
if [ "x$FS" = "xZFS" ] # Vigrid ZFS daemon update script
then
  Display -h "  Enabling vigrid-ZFSexportUPD service..."
  cp /Vstorage/GNS3/vigrid/lib/systemd/system/vigrid-ZFSexportUPD.service /lib/systemd/system/ || Error 'Install failed,'
  systemctl enable vigrid-ZFSexportUPD || Error 'Cant enable vigrid-ZFSexportUPD,'
fi

Display "Setting gns3 owner of /Vstorage..." && chown -R gns3:gns3 /Vstorage || Error 'chown gns3:gns3 /Vstorage failed,'

Display -h -n "Replacing timesyncd with chrony..."
apt install -y chrony || Error "Chrony add failed,"
apt purge -y systemd-timesyncd || Error "Timesyncd removal failed,"

Display -h -n "Adding miscellaneous packages..."
apt install -y iotop atop sysstat rsync rclone openntpd ntpdate fio || Error "Failed,"

# Adding Vigrid monitoring
Display -h "  Configuring PHP pools..."

PHP_VER=`php -v|head -1|awk '{print $2;}'| awk 'BEGIN { FS="."; } { print $1"."$2; }'`
Display -h "    PHP version is $PHP_VER."

Display -h "    Removing default PHP pools..."
rm /etc/php/$PHP_VER/fpm/pool.d/* || Error 'Cant remove pool,'

Display -h "    Adding Vigrid standard pool..."
cp /Vstorage/GNS3/vigrid/confs/php/php-pfm-pool.d-vigrid-www.conf /etc/php/$PHP_VER/fpm/pool.d/vigrid-www.conf
sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/php/$PHP_VER/fpm/pool.d/vigrid-www.conf

Display -h "Enabling & starting PHP-FPM..."
systemctl enable php$PHP_VER-fpm
service php$PHP_VER-fpm stop
service php$PHP_VER-fpm start

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

cp /Vstorage/GNS3/vigrid/confs/nginx/nginx.conf /etc/nginx/nginx.conf
[ $? -ne 0 ] && Error 'Cant copy nginx.conf, '

cp /Vstorage/GNS3/vigrid/confs/nginx/vigrid-auth.lua /etc/nginx/
[ $? -ne 0 ] && Error 'Cant copy vigrid-auth.lua, exiting'

cp /Vstorage/GNS3/vigrid/confs/nginx/vigrid-cors.conf /etc/nginx/
[ $? -ne 0 ] && Error 'Cant copy vigrid-cors.conf, exiting'

cp /Vstorage/GNS3/vigrid/confs/nginx/vigrid-CyberRange-443-api.conf /etc/nginx/sites/CyberRange-443-api.conf
[ $? -ne 0 ] && Error 'Cant create CyberRange-443-api.conf from template, exiting'

sed -i "s/%%PHP_VER%%/$PHP_VER/" /etc/nginx/sites/CyberRange-443-api.conf
sed -i "s/%%VIGRID_ROOT%%/\/Vstorage\/GNS3\/vigrid/" /etc/nginx/sites/CyberRange-443-api.conf
sed -i "s/%%VIGRID_API%%/vigrid-nas-api/" /etc/nginx/sites/CyberRange-443-api.conf

Display -h "Adding www-data user to gns3 group..."
usermod -a www-data -G gns3 >/dev/null 2>/dev/null || Error 'add failed,'

Display -h "Generating SSL certificate for localhost..."
mkdir -p /etc/nginx/ssl >/dev/null 2>/dev/null
( printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth") | openssl req -x509 -out /etc/nginx/ssl/localhost.crt -keyout /etc/nginx/ssl/localhost.key -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' || Error 'Certificate generation failed,'

Display -h "Enabling & starting OpenResty..."
systemctl enable openresty
service openresty start

Display "Installing & enabling Vigrid-load monitoring..."
cp /Vstorage/GNS3/vigrid/etc/init.d/vigrid-load /etc/init.d/
cp /Vstorage/GNS3/vigrid/etc/logrotate.d/vigrid-load /etc/logrotate.d/
systemctl enable vigrid-load

Display "Normally if you did everything correctly, the Vigrid NAS is ready"

Display "You might wish to know how fast is the $FS filesystem you created ?"
until false
do
  Display -h -n "I can run some benchmark checks so you know what do you have (will take at least 15mn). Ok for you ? [y/N] "
  read ANS
  
  if [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
  then
    fio_work="/$FS_ROOT/tmp/work"
    fio_output="/$FS_ROOT/tmp/output"         
    Display -h "  Ok, creating /$FS_ROOT/tmp $fio_work $fio_output"
    mkdir -p /$FS_ROOT/tmp $fio_work $fio_output || Error "mkdir failed,"
    
    LIST="--bs=64k --rw=read:--bs=64k --rw=write:--bs=8k --rw=randread:--bs=8k --rw=randwrite"
    NR_JOBS="2 4 8 16 32 64"

    IFSBAK=$IFS
    IFS=":"
    for TEST in $LIST
    do
      TESTNAME=`echo $TEST|sed 's/^.*=//'`
      IFS=$IFSBAK
      
      for i in $NR_JOBS
      do 
        Display -h "  Running fio: $TEST (threads=$i)"
        time fio --name=fiotest --directory=$fio_work --direct=1 --numjobs=$i --nrfiles=4 --runtime=30 --group_reporting --time_based --stonewall --size=4G --ramp_time=20 $TEST --iodepth=8 --fallocate=none --output=$fio_output/$TESTNAME-$i.txt >/dev/null 2>/dev/null
        RC=$?
        if [ $RC -eq 0 ]
        then
          cat $fio_output/$TESTNAME-$i.txt|head -1| sed 's/^    //'
          cat $fio_output/$TESTNAME-$i.txt|tail -1| sed 's/^    //'
          echo
        fi
      done
    done
  
    break
  elif [ "x$ANS" = "xn" -o "x$ANS" = "xN" -o "x$ANS" = "x" ]
  then
    break
  fi
done

Display "Things you might wish to consider:
- /etc/default/nfs-kernel-server: Number of servers to start up -> RPCNFSDCOUNT=value. To set to number of vCPU available
"

Display "Script finished, all output logged to $LOG_FILE."

) 2>&1 | tee -a $LOG_FILE
