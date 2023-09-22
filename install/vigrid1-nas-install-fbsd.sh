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
Vigrid extension: NAS install script (FreeBSD version)

This script requires to be launched on the latest FreeBSD version, Internet access (for updates & packages) ready.
Additional partitions/disks should be available. I'll ask you about these to create the NAS storage

Upon any issue, script will pause, proposing to (force) continue, run a sub shell or exit procedure.
Everything will be logged to $LOG_FILE.

Upon any question with default answer, validate the choice.
IMPORTANT: if this server is using DHCP, I'll set the IP address to the one obtained.
This IP might change in the future, especially if you select CyberRange designs.

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
OS_RELEASE=`uname -a | awk '{print $1" "$3;}'`
OS_CHK=`echo "$OS_RELEASE" | grep -i "FreeBSD 1"|wc -l`
Display -h -n "I see I am launched on a $OS_RELEASE, "
[ $OS_CHK -ge 1 ] && Display -h "perfect to me !"
[ $OS_CHK -ge 1 ] || Display -h "not the one I expected, not sure I will work fine over it."

# Server update
Display "Lets update your server first"

pkg update || Error "Command exited with an error,"
pkg upgrade || Error "Command exited with an error,"

# Display "Adding Zrepl repository & tool..."
# curl -fsSL https://zrepl.cschwarz.com/apt/apt-key.asc | tee | gpg --dearmor | apt-key add -
# echo "deb https://zrepl.cschwarz.com/apt/ubuntu `lsb_release -cs` main" | tee /etc/apt/sources.list.d/zrepl.list || Error 'Update failed,'
# apt update -y || Error "Command exited with an error,"
# pkg install -y zrepl

Display "Install misc tools..."
pkg install -y ipcalc bash-static lsblk arc_summary ioping

# Filesystem selection

FS="ZFS"
FS_ROOT="Vstorage"

# Disks identification
Display -n "Identifying available hard drives: "
DSK=`geom disk list | grep "^Geom name:" | awk '{print $NF;}'`
Display -h $DSK

Display -h "  Existing partitions (by gpart):"
for i in $DSK
do
  Display -h "  - Disk $i:"
  PART=`gpart show $i 2>/dev/null | tail -n+2|awk '{for(i=3; i<=NF; ++i) printf "%s	", $i; print ""}' | grep "^[0-9]"|sed "s/^/$i"p"/g" | egrep -v "freebsd-(boot|swap)"`
  IFSBAK=$IFS
  IFS="
"
  for j in $PART
  do
    Display -h "    - $j"
  done
  IFS=$IFSBAK
done

# Identify free ones : size >1G, not mounted, not part of a zpool
until false
do
  FREE_PARTS=""
  for i in $DSK
  do
    PART=`gpart show $i 2>/dev/null | tail -n+2| egrep -v "freebsd-(boot|swap)"| awk '{print $3;}' | grep "^[0-9]"|sed "s/^/$i"p"/g"`
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

        # Partition is not part of a zpool
        CHK=`zpool list -v -o name|grep "%"|grep "$j"|wc -l`
        [ $CHK -gt 0 ] && PART_IS_FREE=0

        # Partition must have an acceptable size (G or T)
        PART_DSK=`echo $j | sed 's/p.*//'`
        CHK=`lsblk $PART_DSK|grep $j|awk '{print $3;}'|egrep "[GT]"|wc -l`
        [ $CHK -eq 0 ] && PART_IS_FREE=0
       
        # Still free ? Ok valid !
        [ $PART_IS_FREE -eq 1 ] && FREE_PARTS="$FREE_PARTS $j"
      fi
    done
    IFS=$IFSBAK
  done
  
  # I detected no free partitions
  if [ "x$FREE_PARTS" = "x" ]
  then
    Display -h "(!!) I detected no free partition but I may have made a mistake, I will ask anyway the partition(s) to build the storage"
    if [ "x$DSK" != "x" ]
    then
      Display -h -n "
      
*** However, I detected many disks, do you want me to initialize and create a partition on some of them ? [y/N] "
      read ANS

      if [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
      then
        DSK_NOPART=""
        for i in $DSK
        do
          gpart show $i >/dev/null 2>/dev/null
          [ $? -ne 0 ] && DSK_NOPART="$DSK_NOPART $i"
        done
        
        until false
        do
          Display -h -n "These disks failed to give a partition list: $DSK_NOPART
  Which one to initialize (or enter 'none' to finish) ? "
          read ANS
          [ "x$ANS" = "xnone" ] && break
          CHK=`echo "$DSK_NOPART "|grep "$ANS " | wc -l`
          echo $CHK
          if [ $CHK -gt 0 ]
          then
            Display -h -n "Initializing $ANS..."
            gpart create -s GPT $ANS
            Display -h -n "Creating a single ZFS partition on $ANS..."
            gpart add -t FreeBSD-ZFS $ANS
            Display -h "done...
"
          fi
        done
        
      fi
    fi
  fi

  until false
  do
    Display -h "Please provide a space separated list of FREE partition(s)/full device(s) that will be used for the $FS storage from: $FREE_PARTS"
    Display -h "Enter 'none' to avoid this stage..."
    read FS_PARTS
    [ "x$FS_PARTS" != "x" ] && break
    [ "x$FS_PARTS" = "xnone" ] && break
  done

  if [ "x$FS_PARTS" != "xnone" ]
  then
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
        fi
        
        read FS_TYPE
        
        [ $FS_TYPE -eq 0 -o $FS_TYPE -eq 1 -o $FS_TYPE -eq 5 -o $FS_TYPE -eq 6 ] && break
        [ "x$FS" = "xZFS" -a $FS_TYPE -eq 7 ] && break
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
      
      Display -h "  Setting compression..."
      zfs set compression=lz4 $FS_ROOT || Error "Cant set lz4 compression on $FS_ROOT,"
      
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
      fi  
      
      echo
      echo "Final ZFS pool:"
      zpool status $FS_ROOT
      zfs list $FS_ROOT
    fi # ZFS
  fi
  
  Display "Now checking a Vstorage Zpool exists"
  CHK=`zfs list | grep "^Vstorage "|wc -l`
  if [ $CHK -lt 1 ]
  then
    Display "None found, trying to import possible existing Zpools..."
    zpool import -f -a
  fi
  
  CHK=`zfs list | grep "^Vstorage "|wc -l`
  [ $CHK -lt 1 ]&& Error "Vstorage Zpool does not exist, I am blocked. Please build it or provide free partitions so I can do it."
  
    
  Display "Now creating Vigrid datasets:"
  LIST="Backups ISOimages GNS3 GNS3/GNS3repos GNS3/GNS3farm GNS3/GNS3farm/GNS3 GNS3/GNS3farm/GNS3/images GNS3/GNS3farm/GNS3/projects NFS"
  for i in $LIST
  do
    Display -h "$i..."
    if [ "x$FS" = "xZFS" ]
    then
      zfs create -p $FS_ROOT/$i || Error "Cant create $FS_ROOT/$i,"
    fi
  done

  break  
done
# FS install done

Display "Creating gns3 group..." && pw group add -g 777 -n gns3  2>/dev/null || Error 'Group creation failed,'
Display -h "Creating gns3 user..." && pw user add -u 777 -c "GNS3" -g gns3 -d /Vstorage/GNS3 -g gns3 -n gns3 2>/dev/null || Error 'User creation failed,'

Display "Ok, Vigrid NAS is ready for storing, let's turn it to NFS server now"

Display "Creating /etc/exports file with Vigrid GNS3 farm & repo shared"
echo "#
# Vigrid NAS NFS exports file, v4 format
#
# GLOBAL: GNS3 repositories. Should be shared to Vigrid master GNS3 host only.

V4: /
  /$FS_ROOT/GNS3/GNS3repos                      -mapall 777:777 -alldirs GNS3hosts

# GNS3 Farm: GNS3 shared + docker per host
  /$FS_ROOT/GNS3/GNS3farm/GNS3                  -mapall 777:777 -alldirs GNS3hosts
  /$FS_ROOT/GNS3/GNS3farm/GNS3/images           -mapall 777:777 -alldirs GNS3hosts
  /$FS_ROOT/GNS3/GNS3farm/GNS3/projects         -mapall 777:777 -alldirs GNS3hosts

# GNS3 independant host using NAS: 
# /$FS_ROOT/NFS/[per_host]/GNS3mount                -mapall 777:777 -alldirs [per_host]
# /$FS_ROOT/NFS/[per_host]/GNS3mount/GNS3           -mapall 777:777 -alldirs [per_host]
# /$FS_ROOT/NFS/[per_host]/GNS3mount/GNS3/projects  -mapall 777:777 -alldirs [per_host]
# /$FS_ROOT/NFS/[per_host]/var-lib-docker           -mapall 777:777 -alldirs [per_host]

" >/etc/exports

NCPU=`sysctl hw.ncpu | awk '{print $NF;}'`
NCPU=$((NCPU-2))

Display "Enabling NFS Server"
echo "# Vigrid required services
rpcbind_enable=\"YES\"

nfs_client_enable=\"YES\"
nfs_client_flags=\"-n 4\"
#
nfs_server_flags=\"-u -t -n $NCPU\"
nfs_server_enable=\"YES\"
nfs4_server_enable=\"YES\"
nfsv4_server_only=\"YES\"

vigrid-load_enable=\"YES\"

mountd_enable=\"YES\"
mountd_flags=\"-r\"
" >>/etc/rc.conf

Display -h "Setting NFSd to v3.0-4.2..."
echo "# NFS set to v3.0-4.2
vfs.nfsd.server_max_nfsvers: 4
vfs.nfsd.server_min_nfsvers: 3
vfs.nfsd.server_max_minorversion4: 2
vfs.nfsd.server_min_minorversion4: 0
" >>/etc/sysctl.conf

Display -h "Starting nfsd..."
service nfsd start
Display -h "Starting nfsclient..."
service nfsclient start

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
                  touch /etc/netgroup
                  GNS3HOSTS=`cat /etc/netgroup | egrep "^GNS3hosts\s+"`
                  
                  if [ "x$GNS3HOSTS" = "x" ]
                  then
                    GNS3HOSTS="GNS3hosts ($GNS_NAME,,)"
                    echo "$GNS3HOSTS" >>/etc/netgroup
                  else
                    CHK=`echo "$GNS3HOSTS" | egrep "($GNS_NAME,,)"`
                    if [ "x$CHK" = "x" ]
                    then
                      GNS3HOSTS="$GNS3HOSTS ($GNS_NAME,,)"
                      cat /etc/netgroup | sed "s/^GNS3hosts.*$/$GNS3HOSTS/" >/etc/netgroup.tmp || Error 'Cant update GNS3hosts into /etc/netgroup,'
                      mv /etc/netgroup.tmp /etc/netgroup || Error 'Cant update GNS3hosts into /etc/netgroup,'
                    fi
                  fi
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
      fi
      
      echo "
# Shares for $GNS_NAME
  /$FS_ROOT/NFS/$GNS_NAME/GNS3mount                -mapall 777:777 -alldirs $i
  /$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3           -mapall 777:777 -alldirs $i
  /$FS_ROOT/NFS/$GNS_NAME/GNS3mount/GNS3/projects  -mapall 777:777 -alldirs $i
  /$FS_ROOT/NFS/$GNS_NAME/var-lib-docker           -mapall 777:777 -alldirs $i" >>/etc/exports
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

    Display "
To share resources on a Vigrid NAS, as root:

1- You will have to define into /etc/hosts each of the GNS3 slaves complying with this logic:
[IPaddress]   [gns3hostname]

2- Then you must create the associated ZFS datasets for these hosts, launching as root per host:
$FS_CREATE

3- Finally, you must now edit /etc/exports to define NFS access rights to you shares, create those missings.
   You can follow examples in /etc/exports file.
   
   For a Farm with a MASTER server + 2 slaves and 2 GNS3 independant servers, the below would do:
   # GNS3 Farm
   /$FS_ROOT/NFS/gns3master/GNS3mount/GNS3 -mapall 777:777 -alldirs GNS3master
   /$FS_ROOT/NFS/gns3slave1/var-lib-docker -mapall 777:777 -alldirs GNS3slave1
   /$FS_ROOT/NFS/gns3slave2/var-lib-docker -mapall 777:777 -alldirs GNS3slave2
   
   # GNS3 independant hosts: gns3independant1 & gns3independant2
   /$FS_ROOT/NFS/gns3independant1/GNS3mount/GNS3 -mapall 777:777 -alldirs GNS3independant1
   /$FS_ROOT/NFS/gns3independant1/var-lib-docker -mapall 777:777 -alldirs GNS3independant1

   /$FS_ROOT/NFS/gns3independant2/GNS3mount/GNS3 -mapall 777:777 -alldirs GNS3independant2
   /$FS_ROOT/NFS/gns3independant2/var-lib-docker -mapall 777:777 -alldirs GNS3independant2

4- To regroup GNS3 hosts, you can use /etc/netgoup with the following format:
   GNS3hosts (GNS3master,,) (GNS3slave1,,) (GNS3slave2,,) ...
   Then use 'GNS3hosts' as keyword
   
"
    break
  fi
done

Display "Updating exports..."
service mountd reload

Display -h "
Creating /var/log/gns3 directory for logging..."
mkdir -p /var/log/gns3 || Error "mkdir failed,"

if [ "x$FS" = "xZFS" ] # Vigrid ZFS daemon update script
then
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

which git >/dev/null 2>/dev/null
[ $? -eq 1 ] && pkg install -y git

if [ -d /Vstorage/GNS3/vigrid ]
then
  cd /Vstorage/GNS3/vigrid && git config --global --add safe.directory /Vstorage/GNS3/vigrid && git config pull.rebase false && git pull || echo Vigrid update failed
else
  cd /Vstorage/GNS3 && git clone https://github.com/llevier/vigrid.git || echo Vigrid update failed
fi

echo "Resetting /Vstorage/GNS3 permissions (need root privilege)..."
chown -R gns3:gns3 /Vstorage/GNS3  >/dev/null 2>/dev/null

cp /Vstorage/GNS3/vigrid/etc/rc.d/vigridZFSexportUPD /usr/local/etc/rc.d/ 2>/dev/null

echo
echo Restarting services...
LIST="vigrid-ZFSexportUPD vigrid-load"
for i in $LIST
do
  echo "  $i..."
  
  CHK=`ps ax|grep "vigrid-daemon-ZFSexportsUPD-FreeBSD"|wc -l`
  if [ $CHK -eq 0 ]
  then
    echo "    does not exist in unit files, no action"
  else
    if [ "x$CHK" = "xenabled" ]
    then
      echo "    enabled, restarting it"
      service vigridZFSexportUPD stop
      service vigridZFSexportUPD start
    else
      echo "    disabled, no action"
    fi
  fi
done

echo
echo All done
' >/Vstorage/GNS3/bin/vigrid-update

  chmod 755 /Vstorage/GNS3/bin/vigrid-update || Error 'Cant chmod /home/gns3/bin/vigrid-update,'
  Display -h "  Launching vigrid-update..."
  /Vstorage/GNS3/bin/vigrid-update || Error 'vigrid-update failed,'  
  
  PHP_CLI=`pkg search php | egrep "^php[0-9]+-[0-9]" | sort | awk '{print $1;}'`
  for i in $PHP_CLI
  do
    DEPRECATED=`pkg search -Q annotations "^$i"|grep deprecated`
    if [ "x$DEPRECATED" = "x" ]
    then
      PHP_CLI_FINAL=$i
      break
    fi
  done
  Display "Installing PHP CLI $PHP_CLI_FINAL..." && pkg install -y $PHP_CLI_FINAL || Error 'Install of $PHP_CLI failed,'
  ln -s /usr/local/bin/php /usr/bin/php || Error 'Symlink of $PHP_CLI_FINAL to /usr/bin failed,'
  
  PHP_VERSION=`echo $PHP_CLI_FINAL|sed 's/-.*$//'`
  PHP_EXTENSIONS="$PHP_VERSION-pcntl $PHP_VERSION-posix"
  Display "Installing PHP CLI $PHP_CLI_FINAL..." && pkg install -y $PHP_EXTENSIONS || Error 'Installs of $PHP_EXTENSIONS failed,'
  
  
  Display -h "  Installing vigridZFSexportUPD service..."
  mkdir -p /usr/local/etc/rc.d 2>/dev/null
  cp /Vstorage/GNS3/vigrid/etc/rc.d/vigridZFSexportUPD /usr/local/etc/rc.d/ || Error 'Install failed,'
  echo "# Vigrid ZFS update daemon
vigridZFSexportUPD_enable=\"YES\"
" >>/etc/rc.conf
  service vigridZFSexportUPD start || Error 'Cant start vigrid-ZFSexportUPD,'
fi

Display "Setting gns3 owner of /Vstorage..." && chown -R gns3:gns3 /Vstorage || Error 'chown gns3:gns3 /Vstorage failed,'

Display -h -n "Adding miscellaneous packages..."
pkg install -y rsync rclone fio || Error "Failed,"

# Adding Vigrid monitoring
Display "Installing & enabling Vigrid-load monitoring..."
cp /Vstorage/GNS3/vigrid/etc/init.d/vigrid-load /usr/local/etc/rc.d/
/usr/local/etc/rc.d/vigrid-load start

Display "Normally if you did everything correctly, the Vigrid NAS is ready"
service mountd reload

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

Display "Script finished, all output logged to $LOG_FILE."

) 2>&1 | tee -a $LOG_FILE
