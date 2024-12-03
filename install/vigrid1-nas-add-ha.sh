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
LOG_FILE="/$SCRIPT_NAME-log.out"

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
Vigrid extension: High Availability NAS install script

NOTA:
	That design will create a ZFS Highly Available Storage on 2 nodes only.
	Such a ZFS Highly Available Storage where hard drives are not shared between hosts is much more risky.
	Accordingly 2 MAJOR RECOMMANDATIONS:
		1- You should prefer setting up a 'shared hard drives' (multipath) cluster, but this is more expensive (daisy chained disk shelves extensions). You will find plenty of howto's set that up on Internet.
		2- You should backup periodicly this cluster to prevent split-brain or data loss issues.

This script requires strict rules:
1- Primary Vigrid-NAS *must be under ZFS*
2- Primary Vigrid-NAS must be backed up (*ZFS pool will be rebuilt and so data will be destroyed*)
   *BACKUP should include all ZFS datasets and possibly snapshots.*
3- Hardware used for ZFS pool should be identical.
4- This script must be ran on a ready Vigrid-NAS that will be used as Secondary Vigrid-NAS.

Upon any issue, script will pause, proposing to (force) continue, run a sub shell or exit procedure.
Everything will be logged to $LOG_FILE.

Upon any question with default answer, validate the choice.
IMPORTANT: if this server is using DHCP, I'll set the IP address to the one obtained. This IP might change in the future,
especially if you select CyberRange designs.

If you are all these rules as satisfied, please press [RETURN]..."
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

VIGRID_NAS_CHECK=`ps axo command|grep vigrid`
CHK=`echo "$VIGRID_NAS_CHECK" | egrep "^php-fpm: pool vigrid-www"`
[ "x$CHK" = "x" ] && Error "I am sorry but I cant detect Vigrid-NAS PHP pool,"
CHK=`echo "$VIGRID_NAS_CHECK" | grep "vigrid-daemon-ZFSexportsUPD"`
[ "x$CHK" = "x" ] && Error "I am sorry but I cant detect a running vigrid-daemon-ZFSexportsUPD,"
CHK=`echo "$VIGRID_NAS_CHECK" | grep "\/vigrid-load"`
[ "x$CHK" = "x" ] && Error "I am sorry but I cant detect a running vigrid-load,"

Display -n -h "Ok I can detect all Vigrid-NAS daemons, let's proceed"

Display "Now let's check how much RAM server has"
RAM=`free -g|head -2|tail -1|awk '{print $2;}'`
[ $RAM -le 32 ] && Display -h "Server has less than 32GB of physical RAM. With ZFS, it is advise to have much more. I advise 128GB of RAM"

# Server update
Display "Lets update your server first"

apt update -y || Error "Command exited with an error,"
apt full-upgrade -y || Error "Command exited with an error,"
apt autoclean -y || Error "Command exited with an error,"
apt autoremove -y || Error "Command exited with an error,"

CHK=`which sipcalc`
if [ "x$CHK" = "x" ]
then
  Display "Installing sipcalc"
  apt install -y sipcalc || Error 'Install failed,'
fi

Display -h "Installing SSHpass..."
apt install -y sshpass 2>/dev/null

until false
do
	Display -n "I need Vigrid-Master IP address to extract Vigrid architecture configuration details.
Please provide its IP address: "
	read VIGRID_MASTER_SERVER_IP
	
	CHK=`sipcalc $VIGRID_MASTER_SERVER_IP|grep "^-\[ERR : "|wc -l`
	[ $CHK -eq 0 ] && break
done

IP_ADDR=`ip addr | egrep "^[0-9]|inet "|egrep -v " (lo:|host lo)"|grep "inet "`
CHK=`echo "$IP_ADDR" |wc -l`
[ $CHK -gt 1 ] && Error "I detect more than one IP address on this Vigrid-NAS, please remove the useless one(s)."

NASBIS_IP_FULL=`echo "$IP_ADDR" | sed 's/^.*inet //;s/ .*$//'`
NASBIS_IP_BITS=`echo "$NASBIS_IP_FULL" | sed 's/^.*\///'`
NASBIS_IP=`echo "$NASBIS_IP_FULL" | sed 's/\/.*$//'`
NASBIS_HOSTNAME=`hostname | tr /A-Z/ /a-z/`
Display -n -h "I see my IP address is $NASBIS_IP and my name is $NASBIS_HOSTNAME"

SSHOPTIONS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'
until false
do
	Display -n "I need Vigrid-Master root password to interface with it: "
	read -s SSHPASS
	[ "x$SSHPASS" != "x" ] && break
done
export SSHPASS

Display "Getting Vigrid Master hostname..."
VIGRID_MASTER_SERVER_NAME=`sshpass -e ssh $SSHOPTIONS root@$VIGRID_MASTER_SERVER_IP hostname`

Display "Extracting configuration details I need..."
Display -h "  Vigrid configuration:"
sshpass -e scp $SSHOPTIONS root@$VIGRID_MASTER_SERVER_IP:/home/gns3/etc/vigrid.conf /root/ || Error "I cant get vigrid.conf file from $VIGRID_MASTER_SERVER_IP, "
Display -h "Integrating Vigrid configuration..."
. /root/vigrid.conf || Error "I cant integrate Vigrid configuration, "
rm /root/vigrid.conf

VIGRID_SSHKEY_OPTIONS="$VIGRID_SSHKEY_OPTIONS -o LogLevel=ERROR"

Display -h "  Vigrid NAS SSH key ($VIGRID_SSHKEY_NAS):"
[ "x$VIGRID_SSHKEY_NAS" = "x" ] && Error "I am sorry but I cant determine Vigrid-NAS SSH key, "
VIGRID_SSHKEY_NAS_BASE=`basename $VIGRID_SSHKEY_NAS`

mkdir -p /root/.ssh 2>/dev/null
sshpass -e scp $SSHOPTIONS root@$VIGRID_MASTER_SERVER_IP:$VIGRID_SSHKEY_NAS /root/.ssh/
VIGRID_SSHKEY_NAS="/root/.ssh/$VIGRID_SSHKEY_NAS_BASE"
chmod 600 $VIGRID_SSHKEY_NAS

VIGRID_NAS_SERVER_NAME=`echo $VIGRID_NAS_SERVER|awk -F ':' '{print $1;}' | tr /A-Z/ /a-z/`
VIGRID_NAS_SERVER_IP=`echo $VIGRID_NAS_SERVER|awk -F ':' '{print $2;}'`

Display "Defining these hosts on both $VIGRID_NAS_SERVER_NAME & $NASBIS_HOSTNAME..."
echo "$VIGRID_NAS_SERVER_IP	$VIGRID_NAS_SERVER_NAME" >>/etc/hosts
echo "$NASBIS_IP $NASBIS_HOSTNAME" | ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP 'cat >>/etc/hosts' || Error 'I cant update /etc/hosts on $VIGRID_NAS_SERVER_NAME,'

Display "I will now need to define a HA synchronisation link. 
Link must be on a dedicated network interface with a speed at least as fast as interface hosting NFS to the Vigrid infrastructure
Let me check what is available on $NASBIS_HOSTNAME..."

NICS=`ip link | egrep "^[0-9]"|grep -v "lo:"|awk '{print $2;}'|sed 's/://'`
HA_NIC_LOCAL=""
for i in $NICS
do
  NIC_IP=`ip addr sh $i|grep "inet "`
	# echo  "$i: $NIC_IP"
	[ "x$NIC_IP" = "x" ] && HA_NIC_LOCAL=$i && break
done
[ "x$HA_NIC_LOCAL" = "x" ] && Error "I cant find a free network interface (no IP address then) on $NASBIS_HOSTNAME,"
Display -h "$HA_NIC_LOCAL is available on $NASBIS_HOSTNAME, using it."

Display -h "on $VIGRID_NAS_SERVER_NAME..."
NICS=`ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP ip link | egrep "^[0-9]"|grep -v "lo:"|awk '{print $2;}'|sed 's/://'`
HA_NIC_REMOTE=""
for i in $NICS
do
  NIC_IP=`ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP ip addr sh $i|grep "inet "`
	[ "x$NIC_IP" = "x" ] && HA_NIC_REMOTE=$i && break
done
[ "x$HA_NIC_REMOTE" = "x" ] && Error "I cant find a free network interface (no IP address then) on $VIGRID_NAS_SERVER_NAME, "
Display -h "$HA_NIC_REMOTE is available on $VIGRID_NAS_SERVER_NAME, using it."

Display "I will need now you to define an IP address in the same LAN for the HA sync link."

until false
do
	Display -h -n "Please provide an IP address for $NASBIS_HOSTNAME:"
	read HA_NIC_LOCAL_IP

	CHK=`sipcalc $HA_NIC_LOCAL_IP|grep "^-\[ERR : "|wc -l`
	[ $CHK -eq 0 ] && break
done

until false
do
	Display -h -n "Please provide an IP address for $VIGRID_NAS_SERVER_NAME:"
	read HA_NIC_REMOTE_IP

	CHK=`sipcalc $HA_NIC_REMOTE_IP|grep "^-\[ERR : "|wc -l`
	[ $CHK -eq 0 ] && break
done

until false
do
	Display -h -n "Please provide an bit mask (from 8 to 30) for HA link IP range:"
	read HA_NIC_BITS

	CHK=`echo $HA_NIC_BITS | bc -s`
	[ $CHK -le 30 -a $CHK -ge 8 ] && break
done

HA_NIC_LOCAL_BASE=`sipcalc $HA_NIC_LOCAL_IP/$HA_NIC_BITS | grep "^Network address" | awk '{print $NF;}'`
HA_NIC_REMOTE_BASE=`sipcalc $HA_NIC_REMOTE_IP/$HA_NIC_BITS | grep "^Network address" | awk '{print $NF;}'`
[ "x$HA_NIC_LOCAL_BASE" != "x$HA_NIC_REMOTE_BASE" ] && Error "I am sorry but these IP addresses are not in the same LAN, "

Display "Defining these hosts on both $VIGRID_NAS_SERVER_NAME & $NASBIS_HOSTNAME. Name will be hostname-halink..."
echo "$HA_NIC_REMOTE_IP	$VIGRID_NAS_SERVER_NAME-halink
$HA_NIC_LOCAL_IP $NASBIS_HOSTNAME-halink" >>/etc/hosts
echo "$HA_NIC_LOCAL_IP $NASBIS_HOSTNAME-HAlink
$HA_NIC_REMOTE_IP	$VIGRID_NAS_SERVER_NAME-halink" | ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP 'cat >>/etc/hosts' || Error 'I cant update /etc/hosts on $VIGRID_NAS_SERVER_NAME,'

Display -h "Now configuring $NASBIS_HOSTNAME HA link..."
echo "network:
  version: 2
  ethernets:
    $HA_NIC_LOCAL:
      addresses:
      - \"$HA_NIC_LOCAL_IP/$HA_NIC_BITS\"
" >/etc/netplan/70-vigrid-halink.yaml
chmod 600 /etc/netplan/70-vigrid-halink.yaml
netplan apply

Display -h "Now configuring $VIGRID_NAS_SERVER_NAME HA link..."
echo "network:
  version: 2
  ethernets:
    $HA_NIC_REMOTE:
      addresses:
      - \"$HA_NIC_REMOTE_IP/$HA_NIC_BITS\"
" | ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP 'cat >/etc/netplan/70-vigrid-halink.yaml'
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP chmod 600 /etc/netplan/70-vigrid-halink.yaml
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP netplan apply

Display -h "Checking HA link answers..."
ping -q -c 3 $HA_NIC_REMOTE_IP || Error "Remote HA link does not answer, "
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS $VIGRID_NAS_SERVER_IP ping -q -c 3 $HA_NIC_LOCAL_IP || Error "I dont answer on local HA link, "

Display "Adding High Availability tools on $NASBIS_HOSTNAME"
apt install -y multipath-tools multipath-tools-boot || Error "Cant install multipath-tools or multipath-tools-boot, "
apt install -y lsscsi crmsh pacemaker corosync heartbeat drbd-utils || Error "Cant install lsscsi, pacemaker,crmsh, heartbeat, drbd-utils or corosync, "

Display "Adding High Availability tools on $VIGRID_NAS_SERVER_NAME"
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP apt install -y multipath-tools multipath-tools-boot || Error "Cant install multipath-tools or multipath-tools-boot, "
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP apt install -y lsscsi crmsh pacemaker corosync heartbeat drbd-utils || Error "Cant install lsscsi, pacemaker,crmsh, drbd-utils, heartbeat or corosync, "

Display "Setting $VIGRID_MASTER_SERVER_NAME as postfix relayhost..."
sed -i "s/^relayhost.*$/relayhost=$VIGRID_MASTER_SERVER_NAME/" /etc/postfix/main.cf
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP sed -i "s/^relayhost.*$/relayhost=$VIGRID_MASTER_SERVER_NAME/" /etc/postfix/main.cf

Display "Downloading ZFS zpool Pacemaker OCF agent..."
rm /usr/lib/ocf/resource.d/heartbeat/ZFS 2>/dev/null
wget -c -O /usr/lib/ocf/resource.d/heartbeat/ZFS https://raw.githubusercontent.com/ClusterLabs/resource-agents/refs/heads/main/heartbeat/ZFS || Error "Cant wget agent to /usr/lib/ocf/resource.d/heartbeat/, "
sed -i '0,/^$/s//OCF_ROOT=\/usr\/lib\/ocf\n/' /usr/lib/ocf/resource.d/heartbeat/ZFS
chmod +x /usr/lib/ocf/resource.d/heartbeat/ZFS || Error "Cant chmod /usr/lib/ocf/resource.d/heartbeat/ZFS, "
scp -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS /usr/lib/ocf/resource.d/heartbeat/ZFS root@$VIGRID_NAS_SERVER_IP:/usr/lib/ocf/resource.d/heartbeat/ZFS || Error 'Cant copy ZFS hearbeat resource to $VIGRID_NAS_SERVER_NAME, '

until false
do
  Display -h -n "Please provide a name for the Vigrid-NAS cluster: "
	read HA_CLUSTER_NAME
	[ "x$HA_CLUSTER_NAME" != "x" ] && break
done

HA_CLUSTER_IP_RANGE=`sipcalc $NASBIS_IP_FULL | grep "^Usable range" | sed 's/^Usable range\s*- //'`
until false
do
  Display -h "The Vigrid-NAS cluster will need a shared IP address inside the LAN range ($HA_CLUSTER_IP_RANGE)."
	Display -n "Please provide that IP address: "
	read HA_CLUSTER_IP
	CHK=`sipcalc $HA_CLUSTER_IP/$NASBIS_IP_BITS| grep "^Usable range" | sed 's/^Usable range\s*- //'`
	[ "x$CHK" = "x$HA_CLUSTER_IP_RANGE" ] && break
  Display -h "I am sorry but that IP is not in $HA_CLUSTER_IP_RANGE"
done

VIGRID_STORAGE_POOL=`echo "$VIGRID_STORAGE_ROOT" | sed 's/^\///'`

Display -h "Identifying $VIGRID_STORAGE_POOL devices on $VIGRID_NAS_SERVER_NAME..."
if [ "x$VIGRID_STORAGE_MODE" = "xZFS" ]
then
	ZPOOL_DISKS=`ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP zpool status -P $VIGRID_STORAGE_POOL |grep -A 50 "NAME"|awk '!NF {exit} {print}'`
	POOL_DISKS=`echo "$ZPOOL_DISKS" | awk '/NAME/{flag=1; next} /logs|cache/{flag=0} flag {print $1}'`
	POOL_DISKS=`echo $POOL_DISKS|sed "s/$VIGRID_STORAGE_POOL//g"`
	POOL_ZIL=`echo "$ZPOOL_DISKS" | awk '/logs/{flag=1; next} /cache|spares|errors/{flag=0} flag {print $1}'`
	POOL_ZIL=`echo $POOL_ZIL`
	POOL_CACHE=`echo "$ZPOOL_DISKS" | awk '/cache/{flag=1; next} /logs|spares|errors/{flag=0} flag {print $1}'`
	POOL_CACHE=`echo $POOL_CACHE`
elif [ "x$VIGRID_STORAGE_MODE" = "xBTRfs" ]
then
	POOL_DISKS=`ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP btrfs filesystem show $VIGRID_STORAGE_ROOT | awk '/devid/{print $NF}'`
fi

if [ "x$POOL_DISKS" = "x" ]
then
	Display -h -n "I dont have a device list for $VIGRID_STORAGE_POOL pool, please provide list of devices including /dev and separated with a space:"
	read POOL_DISKS
	
	[ "x$POOL_DISKS" != "x" ] && break
fi

Display -h "Stopping Vigrid services + exporting ZFS pool on both Vigrid NAS..."
LIST="nfs-kernel-server vigrid-load vigrid-ZFSexportUPD"
for i in $LIST
do
	Display -h "Stopping $i service on cluster hosts..."
	service $i stop || Error "I cant stop $i service on $NASBIS_HOSTNAME,"
	ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP service $i stop || Error "I cant stop $i service on $VIGRID_NAS_SERVER_NAME,"
done
zpool export $VIGRID_STORAGE_POOL 2>/dev/null
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP zpool export $VIGRID_STORAGE_POOL 2>/dev/null

Display "Creating HA Cluster $HA_CLUSTER_NAME..."
Display -h "Creating DRBD shared storage..."

echo "resource $VIGRID_STORAGE_POOL {
  net {
    cram-hmac-alg   sha1;
    shared-secret   \"$HA_CLUSTER_PASS\";
    protocol  C; 

		allow-two-primaries no;
		# fencing resource-only;
		
		# split-brain policy
    after-sb-0pri discard-zero-changes;
    after-sb-1pri discard-secondary;
    after-sb-2pri disconnect;
  }
	syncer {
		verify-alg sha1;
	}
	handlers { 
    fence-peer \"/usr/lib/drbd/crm-fence-peer.9.sh\";
    after-resync-target \"/usr/lib/drbd/crm-unfence-peer.9.sh\";
  }

" >/etc/drbd.d/$VIGRID_STORAGE_POOL.res || Error 'Cant create $VIGRID_STORAGE_POOL.res, '

VOL=0
for i in $POOL_DISKS
do
  DISK=$i
  CHK=`echo $i|grep "\/dev\/"`
	[ "x$CHK" = "x" ] && DISK="/dev/$i"

	echo "  volume $VOL {
    device /dev/drbd$VOL;
    disk $DISK;
    meta-disk internal;
  }" >>/etc/drbd.d/$VIGRID_STORAGE_POOL.res || Error 'Cant update $VIGRID_STORAGE_POOL.res, '
	
	VOL=$((VOL+1))
done
echo "
  on $VIGRID_NAS_SERVER_NAME {
    address $HA_NIC_REMOTE_IP:7789;
  }
  on $NASBIS_HOSTNAME {
    address $HA_NIC_LOCAL_IP:7789;
  }
}
" >>/etc/drbd.d/$VIGRID_STORAGE_POOL.res || Error 'Cant finalize $VIGRID_STORAGE_POOL.res, '

scp -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS /etc/drbd.d/$VIGRID_STORAGE_POOL.res root@$VIGRID_NAS_SERVER_IP:/etc/drbd.d/$VIGRID_STORAGE_POOL.res || Error "I cant copy $VIGRID_STORAGE_POOL.res to $VIGRID_NAS_SERVER_NAME, "

HA_CLUSTER_PASS=`openssl rand -base64 32 | tr -dc '[:alnum:]' | cut -c 1-20`
Display -n "I generated a random secure password for the HA cluster. Please keep it in a safe place. It will be:
$HA_CLUSTER_PASS

######################################################################################################
Next action will destroy the ZFS pool on both Primary & Secondary Vigrid NAS.
Make sure you performed & validated all datasets of your Vigrid NAS has been saved.
Failure to answer 'yes' in the delay (ssh action on $VIGRID_NAS_SERVER_NAME) will fail the entire process.
######################################################################################################

Press [RETURN] once you saved the password and you are ready to continue "
read ANS

Display "
Activating DRBD resource on Primary $VIGRID_NAS_SERVER_NAME...

PLEASE CONFIRM DATA OVERWRITE ANSWERING 'yes' to all requests.
"
drbdadm create-md $VIGRID_STORAGE_POOL
drbdadm up $VIGRID_STORAGE_POOL

Display -h "Activating DRBD resource on Secondary ..."
ssh -t -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP drbdadm create-md $VIGRID_STORAGE_POOL || Error "Cant create DRBD $VIGRID_STORAGE_POOL on $VIGRID_NAS_SERVER_IP, "
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP drbdadm up $VIGRID_STORAGE_POOL || Error "Cant raise DRBD $VIGRID_STORAGE_POOL on $VIGRID_NAS_SERVER_IP, "

drbdadm -- --overwrite-data-of-peer primary $VIGRID_STORAGE_POOL
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP drbdadm secondary $VIGRID_STORAGE_POOL

Display -h "Setting password for hacluster user on $NASBIS_HOSTNAME..."
echo "hacluster:$HA_CLUSTER_PASS" | chpasswd
Display -h "Setting password for hacluster user on $VIGRID_NAS_SERVER_NAME..."
echo "hacluster:$HA_CLUSTER_PASS" | ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP chpasswd

Display -h "Initializing HA Cluster $HA_CLUSTER_NAME..."
pcs host auth $NASBIS_HOSTNAME addr=$NASBIS_IP -u hacluster -p "$HA_CLUSTER_PASS"
pcs host auth $VIGRID_NAS_SERVER_NAME addr=$VIGRID_NAS_SERVER_IP -u hacluster -p "$HA_CLUSTER_PASS"
pcs host auth $NASBIS_HOSTNAME-halink addr=$HA_NIC_LOCAL_IP -u hacluster -p "$HA_CLUSTER_PASS"
pcs host auth $VIGRID_NAS_SERVER_NAME-halink addr=$HA_NIC_REMOTE_IP -u hacluster -p "$HA_CLUSTER_PASS"
pcs cluster setup --force $HA_CLUSTER_NAME $NASBIS_HOSTNAME $VIGRID_NAS_SERVER_NAME

sed -i "0,/totem.*$/s//&\n    rrp_mode: passive/" /etc/corosync/corosync.conf
sed -i "0,/ring0_addr: $VIGRID_NAS_SERVER_IP/s//&\n        ring1_addr: $HA_NIC_REMOTE_IP/" /etc/corosync/corosync.conf
sed -i "0,/ring0_addr: $HA_NIC_REMOTE_IP/s//&\n        ring1_addr: $VIGRID_NAS_SERVER_IP/" /etc/corosync/corosync.conf
sed -i "0,/ring0_addr: $NASBIS_IP/s//&\n        ring1_addr: $HA_NIC_LOCAL_IP/" /etc/corosync/corosync.conf
sed -i "0,/ring0_addr: $HA_NIC_LOCAL_IP/s//&\n        ring1_addr: $NASBIS_IP/" /etc/corosync/corosync.conf

scp -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS /etc/corosync/corosync.conf root@$VIGRID_NAS_SERVER_IP:/etc/corosync/corosync.conf || Error "I cant copy corosync.conf to $VIGRID_NAS_SERVER_IP, "

LIST="corosync pacemaker heartbeat pcsd"
for i in $LIST
do
	Display -h "Enabling $i service on cluster hosts..."
	systemctl enable --now $i || Error "I cant enable $i service on $NASBIS_HOSTNAME,"
	ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP systemctl enable --now $i || Error "I cant enable $i service on $VIGRID_NAS_SERVER_NAME,"
done

Display -h 'Waiting for DRBD disks to be synchronized...'
until false
do
  CHK=`drbdsetup status $VIGRID_STORAGE_POOL --verbose --statistics|grep "disk:"`

	VOLS=`echo "$CHK" | grep " disk:" | sed 's/^.*volume://g;s/ .*$//g'`
  for i in $VOLS
	do	
		DISK[$i]=`echo "$CHK" | grep "volume:$i.* disk:" | head -1| sed 's/^.* disk://'`
		DISK_PEER[$i]=`echo "$CHK" | grep "volume:$i.* peer-disk:" | tail -1 | sed 's/^.* peer-disk://' | sed 's/ .*$//'`

		LINE=`echo "$CHK" | grep "volume:$i.* peer-disk:.* done:"`
		[ "x$LINE" != "x" ] && echo "$LINE"
	done
	echo

  BREAK=1
	for i in "${DISK[@]}"
	do
		[[ $i != "UpToDate" ]] && BREAK=0
	done
	for i in "${DISK_PEER[@]}"
	do
		[[ $i != "UpToDate" ]] && BREAK=0
	done

  [ $BREAK -eq 1 ] && break
	sleep 5
done

Display "Creating Vigrid ZFS pool using HW details from Vigrid NAS $VIGRID_NAS_SERVER_NAME...."
DRDB_DISKS=""
VOL=0
for i in $POOL_DISKS
do
	DRBD_DISKS="$DRBD_DISKS drbd$VOL"
	VOL=$((VOL+1))
done
DRBD_DISKS=`echo $DRBD_DISKS`

if [ "x$VIGRID_STORAGE_MODE" = "xZFS" ]
then
	zpool create -f $VIGRID_STORAGE_POOL $DRBD_DISKS

	# cache must be local, it is non-sense to put them on a (slower) shared disk !
	# Keep in mind Vigrid NAS *must* have the same disk design and so device names...
	if [ "x$POOL_CACHE" != "x" ]
	then
		zpool add $VIGRID_STORAGE_POOL cache $POOL_CACHE || Error "Cant add cache devices ($POOL_CACHE) to ZFS pool $VIGRID_STORAGE_POOL, "
	fi

	# same for ZIL
	if [ "x$POOL_ZIL" != "x" ]
	then
		zpool add $VIGRID_STORAGE_POOL log $POOL_ZIL || Error "Cant add log devices ($POOL_ZIL) to ZFS pool $VIGRID_STORAGE_POOL, "
	fi

	Display -h "  Setting ZFS compression..."
	zfs set compression=lz4 $VIGRID_STORAGE_POOL || Error "Cant set lz4 compression on $VIGRID_STORAGE_POOL,"

	Display -h "  Setting ZFS sync to standard..."
	zfs set sync=standard $VIGRID_STORAGE_POOL || Error "Cant set value on $VIGRID_STORAGE_POOL,"

	Display -h "  Setting ZFS atime to off..."
	zfs set atime=off $VIGRID_STORAGE_POOL || Error "Cant set value on $VIGRID_STORAGE_POOL,"

	Display -h "  Setting ZFS xattr to sa..."
	zfs set xattr=sa $VIGRID_STORAGE_POOL || Error "Cant set value on $VIGRID_STORAGE_POOL,"

	Display -h "  Setting ZFS redundant_metadata to most..."
	zfs set redundant_metadata=most $VIGRID_STORAGE_POOL || Error "Cant set value on $VIGRID_STORAGE_POOL,"

	for i in `ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP  egrep -v "^#" /etc/exports | awk '{print $1;}'| sed 's/^\///'`
	do
		echo "  Creating dataset: $i"
		zfs create -p $i || Error "Cant create $i..."
	done
elif [ "x$VIGRID_STORAGE_MODE" = "xBTRfs" ]
then
  	btrfs sub create $VIGRID_STORAGE_ROOT $DRDB_DISKS
fi

Display -h "Moving /etc/exports to $VIGRID_STORAGE_ROOT/nfs-exports..."
scp -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP:/etc/exports /$VIGRID_STORAGE_ROOT/nfs-exports
rm /etc/exports
ln -s /$VIGRID_STORAGE_ROOT/nfs-exports /etc/exports

ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP rm /etc/exports
ssh -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP ln -s /$VIGRID_STORAGE_ROOT/nfs-exports /etc/exports

scp -i $VIGRID_SSHKEY_NAS $VIGRID_SSHKEY_OPTIONS root@$VIGRID_NAS_SERVER_IP:/etc/hosts /etc/hosts || Error "I cant copy host file from $VIGRID_NAS_SERVER_NAME, "

Display -h "Configuring resources..."
crm -F configure primitive $VIGRID_STORAGE_POOL-drbd ocf:linbit:drbd \
    params drbd_resource=$VIGRID_STORAGE_POOL \
    op monitor interval=15s role=Master \
    op monitor interval=30s role=Slave || Error 'Cant create $VIGRID_STORAGE_POOL DRBD resource, '
crm -F configure clone $VIGRID_STORAGE_POOL-drbd-master $VIGRID_STORAGE_POOL-drbd \
    meta clone-max=2 clone-node-max=1 notify=true

crm -F configure primitive $VIGRID_STORAGE_POOL-ZFS ocf:heartbeat:ZFS \
    params pool="$VIGRID_STORAGE_POOL" \
    op start interval=0 timeout=60s \
    op stop interval=0 timeout=60s \
    op monitor interval=30s
crm -F configure colocation zfs-after-drbd inf: $VIGRID_STORAGE_POOL-ZFS $VIGRID_STORAGE_POOL-drbd-master:Master
crm -F configure order drbd-before-zfs Mandatory: $VIGRID_STORAGE_POOL-drbd-master:promote $VIGRID_STORAGE_POOL-ZFS:start

crm -F configure primitive $VIGRID_STORAGE_POOL-VIP ocf:heartbeat:IPaddr2 \
    params ip=$HA_CLUSTER_IP cidr_netmask=$NASBIS_IP_BITS \
    op monitor interval=30s

crm -F configure primitive NFS-server systemd:nfs-server \
    op monitor interval=30s timeout=90s

crm -F configure colocation nfs-with-zfs inf: NFS-server $VIGRID_STORAGE_POOL-ZFS
crm -F configure order zfs-before-nfs Mandatory: $VIGRID_STORAGE_POOL-ZFS:start NFS-server:start
crm -F configure colocation ip-with-nfs inf: $VIGRID_STORAGE_POOL-VIP NFS-server
crm -F configure order nfs-before-ip Mandatory: NFS-server:start $VIGRID_STORAGE_POOL-VIP:start

Display -h "Setting $VIGRID_NAS_SERVER_NAME as prefered master..."
pcs constraint location $VIGRID_STORAGE_POOL-drbd-master prefers $VIGRID_NAS_SERVER_NAME

# No watchdog required for only 2 nodes.
# Stonith disabled at end because until that is done, no resource is started :-)
pcs property set stonith-enabled=false
pcs stonith history cleanup
crm resource cleanup

Display -h "DRDB status:"
drbdadm status

Display -h "Cluster Quorum status:"
pcs quorum status

Display -h "Cluster status:"
pcs status

Display -h "I can also use Vigrid Master server as a quorum device to reduce the risk of split-brain situations."

until false
do
	Display -h -n "Do I setup Vigrid Master host $VIGRID_MASTER_SERVER_NAME as a qdevice [Y/n] ? "
	read ANS

	[ "x$ANS" = "xn" -o "x$ANS" = "xN" ] && break
	
	apt install -y corosync-qdevice || Error 'I cant add corosync-qdevice, '

	Display -h "Updating Vigrid Master..."
	sshpass -e ssh $SSHOPTIONS root@$VIGRID_MASTER_SERVER_IP apt install -y pcs corosync-qnetd || Error "I cant add pcs & corosync-qnetd on $VIGRID_MASTER_SERVER_NAME, "
	sshpass -e ssh $SSHOPTIONS root@$VIGRID_MASTER_SERVER_IP pcs qdevice setup model net --enable --start
	echo "hacluster:$HA_CLUSTER_PASS" | sshpass -e ssh $SSHOPTIONS root@$VIGRID_MASTER_SERVER_IP chpasswd  || Error "I cant set hacluster password on $VIGRID_MASTER_SERVER_NAME, "
	
	pcs host auth $VIGRID_MASTER_SERVER_NAME addr=$VIGRID_MASTER_SERVER_IP -u hacluster -p "$HA_CLUSTER_PASS" || Error "I cant device  $VIGRID_MASTER_SERVER_NAME, "
	pcs quorum device --skip-offline add model net host=$VIGRID_MASTER_SERVER_NAME algorithm=ffsplit || Error "I cant add $VIGRID_MASTER_SERVER_NAME into cluster, "

	Display -h "New Quorum status:"
	pcs quorum status
	break
done

Display -h " Common issues and how to solve them:

- split-brain (DRBD is visible on both but NASes are not connected with DRBD):
	Primary NAS: drbdadm connect Vstorage
	Secondary NAS: drbdadm up Vstorage;drbdadm secondary Vstorage;drbdadm -- --discard-my-data connect Vstorage
	
- force Primary NAS to overwrite all on secondary:
	Primary NAS: drbdadm -- --overwrite-data-of-peer primary Vstorage
	
- Start/Stop a cluster node:
  pcs cluster start/stop [nodename] ($HA_CLUSTER_NAME $NASBIS_HOSTNAME-halink or $VIGRID_NAS_SERVER_NAME-halink)
	
- Test cluster failure:
  pcs cluster stop [master hostname] 
"

Display "Script finished, all output logged to $LOG_FILE."

) 2>&1 | tee -a $LOG_FILE
