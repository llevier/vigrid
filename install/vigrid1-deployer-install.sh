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
Vigrid extension: Network Deployment tool for servers

This script should be launched from a Vigrid NAS.
Its purpose is to install a TFTP server and reconfigure DHCP so a Vigrid NAS can be a source of automated operating systems (OS) install.

TFTP will be populated with an Ubuntu LTS, but can be customized for any other desired OS. It can also be used to deploy virtual machines.
TFTP will listen on the Nsuperadmin0 interface.

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

FAIL=0
Display "Checking if we are on a Vigrid NAS..."
if [ -d /Vstorage ]
then
  Display -h -n "  Found a /Vstorage, good. Is this ZFS or BTRfs ? "
  FS=""
  
  zfs list Vstorage >/dev/null 2>/dev/null
  if [ $? -ne 0 ]
  then
    btrfs sub list /Vstorage >/dev/null 2>/dev/null
    if [ $? -ne 0 ]
    then
      Display -d "Apparently none of the two."
      FAIL=1
    else
      Display -d "That is BTRfs."
      FS="BTRfs"
    fi
  else
    Display -d "That is ZFS."
    FS="ZFS"
  fi
fi

[ "x$FS" != "x" -a ! -d /Vstorage/GNS3/vigrid ] && FAIL=1

if [ $FAIL -eq 1 ]
then
  Display "  It seems we are not on a Vigrid NAS... Shall I continue [Y/n] ? "
  read ANS

  if [ "x$ANS" = "xn" -o "x$ANS" = "xN" ]
  then
    Display -h "Ok, exiting then."
    exit 0
  fi
fi

# Server update
Display "Lets update your server first"

apt update -y || Error "Command exited with an error,"
apt full-upgrade -y || Error "Command exited with an error,"
apt autoclean -y || Error "Command exited with an error,"
apt autoremove -y || Error "Command exited with an error,"

Display -h ""
Display -h "Updating Vigrid as well..."
/Vstorage/GNS3/bin/vigrid-update

Display "Checking we satisfy requirements..."
if [ ! -f "/Vstorage/GNS3/vigrid/tftp/grub.cfg-vigrid-gns" ]
then
  Error "I cant find '/Vstorage/GNS3/vigrid/tftp/grub.cfg-vigrid-gns', I need it"
  exit 1
fi

Display -h "Installing misc applications..."
apt install -y sipcalc || Error "Command exited with an error,"

Display -h "Installing TFTPd..."
apt install -y tftpd-hpa || Error "Command exited with an error,"

Display -h "Creating TFTPd directory /Vstorage/tftp"
if [ "x$FS" = "xZFS" ] ;then zfs create Vstorage/tftp || Error "Command exited with an error,";fi
if [ "x$FS" = "xBTRfs" ] ;then btrfs sub create /Vstorage/tftp || Error "Command exited with an error,";fi

Display -h "Reconfiguring TFTPd directory..."
mv /etc/default/tftpd-hpa /etc/default/tftpd-hpa.org || Error "Command exited with an error,"
cat /etc/default/tftpd-hpa.org | sed 's,^TFTP_DIRECTORY=.*,TFTP_DIRECTORY="/Vstorage/tftp",' >/etc/default/tftpd-hpa.tmp || Error "Command exited with an error,"
cat /etc/default/tftpd-hpa.tmp | sed 's,^TFTP_OPTIONS=.*,TFTP_OPTIONS="--secure -v",' >/etc/default/tftpd-hpa || Error "Command exited with an error,"
rm /etc/default/tftpd-hpa.tmp 2>/dev/null

Display -h "Restarting TFTPd..."
systemctl restart tftpd-hpa  || Error "Command exited with an error,"

Display -h ""
Display -h "Installing Apache2..."
apt install -y apache2 || Error "Command exited with an error,"

Display -h "Configuring Apache2 for HTTP access..."
mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.org || Error "Command exited with an error,"
cat /etc/apache2/sites-available/000-default.conf.org | sed 's,^\s*DocumentRoot .*,DocumentRoot /Vstorage/tftp,' >/etc/apache2/sites-available/000-default.conf

Display -h "Restarting Apache2..."
systemctl restart apache2  || Error "Command exited with an error,"

Display -h "Installing DHCPd..."
apt install -y isc-dhcp-server || Error "Command exited with an error,"

Display -h "  Downloading oui as well..."
wget -q -c http://standards.ieee.org/regauth/oui/oui.txt -O /usr/local/etc/oui.txt

Display -h "Extracting Vigrid NAS IP address"
ADMIN_NIC="Nsuperadmin0"
until false
do
  ip link sh $ADMIN_NIC >/dev/null 2>/dev/null
  [ $? -eq 0 ] && break

  Display -h -n "I failed to find $ADMIN_NIC details, maybe it has another name. Please provide it -> "
  read ADMIN_NIC
  [ "x$ADMIN_NIC" = "x" ] && ADMIN_NIC="[empty]"
done

IP_ADDR=`ip addr sh dev $ADMIN_NIC|grep "^\s*inet "|awk '{print $2;}'`
IP_BITMASK=`echo $IP_ADDR| awk -F '/' '{print $NF;}'`
IP_ADDR=`echo $IP_ADDR|awk -F '/' '{print $1;}'`
IP_NETMASK=`sipcalc -c $IP_ADDR| grep "^Network mask" |head -1| awk '{print $NF;}'`
IP_NETADDR=`sipcalc -c $IP_ADDR| grep "^Network address" | awk '{print $NF;}'`
IP_ROUTE=`ip route|grep "^default.*$ADMIN_NIC"|awk '{print $3;}'`

Display -h "Vigrid NAS IP address is $IP_ADDR/$IP_BITMASK ($IP_NETADDR/$IP_NETMASK), default route to $IP_ROUTE"
if [ "x$IP_ADDR" = "x" -o "x$IP_ROUTE" = "x" -o "x$IP_BITMASK" = "x" -o "x$IP_NETMASK" = "x" -o "x$IP_NETADDR" = "x" ]
then
  Error "I failed to get some Vigrid NAS IP details"
fi

POOL_START=""
POOL_END=""
until false
do
  until false
  do
    Display -n "I need a DHCP pool, please provide a starting IP address -> "
    read POOL_START
    CHK=`sipcalc -c $POOL_START 2>&1|grep ERR`
    [ "x$CHK" = "x" ] && break
  done

  until false
  do
    Display -n "For my DHCP pool, please provide a ending IP address     -> "
    read POOL_END
    CHK=`sipcalc -c $POOL_END 2>&1|grep ERR`
    [ "x$CHK" = "x" ] && break
  done

  # Ensuring END is after start :-)
  POOL_START_DEC=`sipcalc -c $POOL_START | grep "^Host address.*decimal"|awk '{print $NF;}'`
  POOL_END_DEC=`sipcalc -c $POOL_END | grep "^Host address.*decimal"|awk '{print $NF;}'`

  POOL_SIZE=$((POOL_END_DEC-POOL_START_DEC))
  if [ $POOL_SIZE -lt 1 ]
  then
    Display "Empty pool, there is a mistake somewhere, please retry..."
  else
    break
  fi
done

DNS_SERVER=""
until false
do
  Display -n "I will also need a DNS resolver, please provide an IP address -> "
  read DNS_SERVER
  CHK=`sipcalc -c $DNS_SERVER 2>&1|grep ERR`
  [ "x$CHK" = "x" ] && break
done


Display -h "Configuring DHCPd..."
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.org || Error "Command exited with an error,"

echo "
# Vigrid DHCPd configuration file
#
default-lease-time 43200;
max-lease-time 86400;

not authoritative;

ddns-update-style none;

option domain-name \"Vigrid\";
option domain-name-servers $DNS_SERVER;
option ntp-servers none;

allow booting;
allow bootp;

option fqdn.no-client-update    on;
option fqdn.rcode2              255;
option pxegrub code 150 = text ;

# promote vendor in dhcpd.leases
set vendor-string = option vendor-class-identifier;

# next server and filename options
next-server $IP_ADDR;

option architecture code 93 = unsigned integer 16 ;
if option architecture = 00:06 {
  filename \"grubia32.efi\";
} elsif option architecture = 00:07 {
  filename \"grubx64.efi\";
} elsif option architecture = 00:09 {
  filename \"grubx64.efi\";
} else {
  filename \"pxegrub\";
}

log-facility local7;

include \"/etc/dhcp/dhcpd.hosts\";
# Vigrid $ADMIN_NIC
subnet $IP_NETADDR netmask $IP_NETMASK {
  pool
  {
    range $POOL_START $POOL_END;
  }

  option subnet-mask $IP_NETMASK;
  option routers $IP_ROUTE;
}
" >/etc/dhcp/dhcpd.conf

Display -h "Restarting DHCPd..."
systemctl restart isc-dhcp-server || Error "Command exited with an error,"

Display -d "  Creating tftp directory for cloud-init Vigrid configuration..."
mkdir -p /Vstorage/tftp/vigrid-gns || Error "Command exited with an error,"

Display -d "  Creating cloud-init metadata..."
echo "
instance-id: vigrid-autoinstall
" >/Vstorage/tftp/vigrid-gns/meta-data

# https://cloudinit.readthedocs.io/en/latest/reference/examples.html
Display -d "  Creating cloud-init userdata..."
cat >/Vstorage/tftp/vigrid-gns/user-data <<_EOF_
#cloud-config
autoinstall:
  version: 1
  # use interactive-sections to avoid an automatic reboot
  #interactive-sections:
  #  - locale
  apt:
    geoip: yes
    preserve_sources_list: false
    primary:
    - arches: [amd64, i386]
      uri: http://archive.ubuntu.com/ubuntu
    - arches: [default]
      uri: http://ports.ubuntu.com/ubuntu-ports
  user-data:
    timezone: Europe/Paris
  # vigrid password is vigrid (openssl passwd -6 -stdin)
  identity:
    hostname: vigrid-autoinstall
    username: vigrid
    password: $6$zTIkph5GOuD2KpdT$VL4.iuZWV1IomfbaZyMda2iLJyEWZG/7ALR6wx1hX.AbFAERxx4agaG8Ro62CMDqZYaWR33CQIZDI4qj862Op/
  # You may change keyboard layout
  keyboard: {layout: fr, variant: ''}
  locale: en_US.UTF-8
  ssh:
    allow-pw: true
    authorized-keys: []
    install-server: true
  storage:
    layout:
      name: lvm
  # https://cloudinit.readthedocs.io/en/0.7.8/topics/examples.html
  # run commands at first boot
  #  runcmd:
  #   - [ ls, -l, / ]
  #   - [ sh, -xc, "echo $(date) ': hello world!'" ]
  # add new packages
  #  packages:
  # - pwgen
_EOF_

# Display -d "  Validating cloud-init image..."
# cloud-init schema --config-file /Vstorage/tftp/vigrid-gns/user-data || Error "Command exited with an error,"

Display "Deploying GRUB images..."
Display -h "  UEFI..."
Display -d "    Making directory..."
mkdir -p /Vstorage/tftp/grub2-cfg || Error "Command exited with an error,"
Display -d "    Making image..."
grub-mkimage -d /usr/lib/grub/x86_64-efi/ -O x86_64-efi -o /Vstorage/tftp/grubx64.efi -p '/grub2-cfg' efinet tftp || Error "Command exited with an error,"
Display -d "    Deploying GRUB files..."
cp -rf /usr/lib/grub/x86_64-efi /Vstorage/tftp/grub2-cfg/ || Error "Command exited with an error,"

Display -d "    Building grub configuration file..."
cat >>/Vstorage/tftp/grub2-cfg/grub.cfg <<_EOF_
default=normal
timeout=20
echo Default PXE global template entry is set to normal boot process

echo "Trying grub2-cfg/grub.cfg-\$net_default_mac"
configfile "grub2-cfg/grub.cfg-\$net_default_mac"

echo "Trying grub.cfg-\$net_default_mac"
configfile "grub.cfg-\$net_default_mac"

insmod part_gpt
insmod fat
insmod chain

menuentry 'Continue normal boot process' --id normal {
  exit
}

menuentry 'Chainload into BIOS bootloader on first disk' --id local_chain_legacy_hd0 {
  set root=(hd0,0)
  chainloader +1
  boot
}

menuentry 'Chainload into BIOS bootloader on second disk' --id local_chain_legacy_hd1 {
  set root=(hd1,0)
  chainloader +1
  boot
}

menuentry 'Chainload Grub2 EFI from ESP' --id local_chain_hd0 {
  echo "Chainloading Grub2 EFI from ESP, enabled devices for booting:"
  ls
  echo "Trying /EFI/ubuntu/grubx64.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/ubuntu/grubx64.efi
  if [ -f ($chroot)/EFI/ubuntu/grubx64.efi ]; then
    chainloader ($chroot)/EFI/ubuntu/grubx64.efi
    echo "Found /EFI/ubuntu/grubx64.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Trying /EFI/debian/grubx64.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/debian/grubx64.efi
  if [ -f ($chroot)/EFI/debian/grubx64.efi ]; then
    chainloader ($chroot)/EFI/debian/grubx64.efi
    echo "Found /EFI/debian/grubx64.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Trying /EFI/redhat/grubx64.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/redhat/grubx64.efi
  if [ -f ($chroot)/EFI/redhat/grubx64.efi ]; then
    chainloader ($chroot)/EFI/redhat/grubx64.efi
    echo "Found /EFI/redhat/grubx64.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Trying /EFI/centos/grubx64.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/centos/grubx64.efi
  if [ -f ($chroot)/EFI/centos/grubx64.efi ]; then
    chainloader ($chroot)/EFI/centos/grubx64.efi
    echo "Found /EFI/centos/grubx64.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Trying /EFI/rocky/grubx64.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/rocky/grubx64.efi
  if [ -f ($chroot)/EFI/rocky/grubx64.efi ]; then
    chainloader ($chroot)/EFI/rocky/grubx64.efi
    echo "Found /EFI/rocky/grubx64.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Trying /EFI/sles/grubx64.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/sles/grubx64.efi
  if [ -f ($chroot)/EFI/sles/grubx64.efi ]; then
    chainloader ($chroot)/EFI/sles/grubx64.efi
    echo "Found /EFI/sles/grubx64.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Trying /EFI/opensuse/grubx64.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/opensuse/grubx64.efi
  if [ -f ($chroot)/EFI/opensuse/grubx64.efi ]; then
    chainloader ($chroot)/EFI/opensuse/grubx64.efi
    echo "Found /EFI/opensuse/grubx64.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Trying /EFI/Microsoft/boot/bootmgfw.efi "
  unset chroot
  # add --efidisk-only when using Software RAID
  search --file --no-floppy --set=chroot /EFI/Microsoft/boot/bootmgfw.efi
  if [ -f ($chroot)/EFI/Microsoft/boot/bootmgfw.efi ]; then
    chainloader ($chroot)/EFI/Microsoft/boot/bootmgfw.efi
    echo "Found /EFI/Microsoft/boot/bootmgfw.efi at $chroot, attempting to chainboot it..."
    sleep 2
    boot
  fi
  echo "Partition with known EFI file not found, you may want to drop to grub shell"
  echo "Available devices are:"
  echo
  ls
  echo
  echo "If you cannot see the HDD, make sure the drive is marked as bootable in EFI and"
  echo "not hidden. Boot order must be the following:"
  echo "1) NETWORK"
  echo "2) HDD"
  echo
  echo "The system will poweroff in 2 minutes or press ESC to poweroff immediately."
  sleep -i 120
  halt
}

menuentry 'Shutdown' {
  halt
}
_EOF_

Display -d "    Creating Vigrid grub configuration file..."
echo "
default=autoinstall
timeout=30
timeout_style=menu

echo \"Trying /grub2-cfg/grub.cfg-\$net_default_mac\"
configfile \"/grub2-cfg/grub.cfg-\$net_default_mac\"

echo \"Trying grub.cfg-\$net_default_mac\"
configfile \"grub.cfg-\$net_default_mac\"

insmod part_gpt
insmod fat
insmod chain

# Marker where to start pushing distrubutions, DO NOT DELETE
# %%DISTROS%%

menuentry 'Continue normal boot process' --id normal {
  exit
}

menuentry 'Chainload into BIOS bootloader on first disk' --id local_chain_legacy_hd0 {
  set root=(hd0,0)
  chainloader +1
  boot
}

menuentry 'Chainload into BIOS bootloader on second disk' --id local_chain_legacy_hd1 {
  set root=(hd1,0)
  chainloader +1
  boot
}
" >/Vstorage/tftp/grub2-cfg/grub.cfg-vigrid-gns

Display -h "  PXE..."
Display -d "    Making directory..."
mkdir -p /Vstorage/tftp/pxegrub-cfg || Error "Command exited with an error,"
Display -d "    Making image..."
grub-mkimage -d /usr/lib/grub/i386-pc/ -O i386-pc-pxe -o /Vstorage/tftp/pxegrub -p '/pxegrub-cfg' pxe tftp || Error "Command exited with an error,"
Display -d "    Deploying PXE files..."
cp -rf /usr/lib/grub/i386-pc /Vstorage/tftp/pxegrub-cfg/ || Error "Command exited with an error,"
Display -d "    Creating PXE grub2 default configuration..."

ln -s ../grub2-cfg/grub.cfg /Vstorage/tftp/pxegrub-cfg/grub.cfg || Error "Command exited with an error,"

Display -d "Creating ISO directory"
mkdir -p /Vstorage/tftp/isos || Error "Command exited with an error,"

Display -n "Identifying OS..."
DISTRO=`lsb_release -a 2>/dev/null | grep "^Description:" | awk -F ':' '{print $NF;}'| tr /A-Z/ /a-z/ | sed 's/ /-/g'| sed 's/-lts//'`
DISTRO=`echo $DISTRO`
DISTRO_ORIGIN=`echo $DISTRO|sed 's/-.*$//'`
DISTRO_RELEASE=`echo $DISTRO|sed 's/^.*-//'`

Display -n "  Found $DISTRO_ORIGIN-$DISTRO_RELEASE"
DISTRO_SOURCE="https://releases.ubuntu.com/"$DISTRO_RELEASE"/"$DISTRO"-live-server-amd64.iso"
DISTRO_SOURCE=`echo $DISTRO_SOURCE | sed 's/ //g'`

Display -h "Downloading distro to /Vstorage/tftp/isos directory..."

Display -d "  Downloading $DISTRO_SOURCE..."
wget -nv -nd -c -P /Vstorage/tftp/isos $DISTRO_SOURCE || Error "Command exited with an error,"
DISTRO_ISO=`basename $DISTRO_SOURCE`
ISO="/Vstorage/tftp/isos/"$DISTRO_ISO

vigrid-deployer-os -a -i "$ISO" -o "$DISTRO_ORIGIN" -r "$DISTRO_RELEASE"

chown -R gns3:gns3 /Vstorage/tftp

Display "Finally enabling Vigrid Deployer daemon..."
cp /Vstorage/GNS3/vigrid/lib/systemd/system/vigrid-deployer.service /lib/systemd/system/ || Error 'Install failed,'
systemctl enable vigrid-deployer || Error 'Cant enable vigrid-deployer,'

Display "Vigrid Deployer install is now finished.

To install a new server:
1- Extract its MAC on the Admin/SAN network interface
2- Add/delete a host with: vigrid-deployer-host  [ -a | -d ] [MAC Address]

To add/delete a new OS:
vigrid-deployer-os [ -a | -d ] -i "filename.iso" -o "DistributionName" -r "release_name"

From this, vigrid-deployer-watcher will glance at DHCPd log files. Upon detection of all required files were successfully requested, it will remove the special file created for [MAC_Address] boot.

You can also update cloud-init install configuration playing with /Vstorage/tftp/vigrid-gns/user-data file.
"

) 2>&1 | tee -a $LOG_FILE
