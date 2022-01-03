### Vigrid framework installation ###

<FONT SIZE=+2><B>Vigrid Server installation</B></FONT><BR>

<HR>
<FONT SIZE=+1><B>Vigrid NAS (Network Attached Storage) or not Vigrid NAS ?</B></FONT><BR>
If you intend to deploy a Vigrid Farm (either for cloning or scalability), you should strongly consider to deploy first a <A HREF="/docs/vigrid1-nas-install.md">Vigrid NAS</A>.<BR>
<FONT SIZE=+1><B>ALSO</B></FONT>:<BR>
In a Vigrid farm, virtual networks are communicating over a private network (Nsuperadmin0). Of course, you can setup your NAS in this LAN but it will then generate a Denial of Service risk, overloading the virtual network impacting Nsuperadmin0 bandwidth.<BR>
So it is advised to have your NAS on the Internet side of the Vigrid farm, normally less loaded.<BR>
It is planned to consider a dedicated NIC for NAS data flows in a future Vigrid version.
<HR>

Before starting, you should be familiar with the <A HREF="/docs/README.md">Vigrid possible architectures</A>, as well as with the <A HREF="/docs/README.md">Vigrid network standards</A>.<BR><BR>

To launch Vigrid Server installation, you must before:
<LI>Setup a Ubuntu LTS server, latest stable version</LI>
<UL>
  <LI>At least 16 GB (32GB advised to avoid Ubuntu update issues) are required for a flat root (/) filesystem</LI>
  <LI>root filesystem format (ext4...) is at your convenience</LI>
</UL>
<LI>Internet access must be available so vigrid can install more Ubuntu packages</LI>
<LI>If you intend to install a standalone server, additional physical disks must be available. Vigrid will propose to configure them according to RAID standards</LI>
<UL><LI>If you have an additional, even small, SSD disk, Vigrid will propose to use it as cache device.</LI>
<LI>If you prefer using hardware controller features for redundancy, that is not an issue for the install script that will then detect a single disk</LI></UL>
<LI>If you intend to install server using central NAS, this NAS must be accessible by the server during installation</LI><BR>

<FONT SIZE=+2><B>Installing a Vigrid Server</B></FONT><BR>

Once your Ubuntu server is ready, logon and launch the below commands from your favorite shell:<BR>
<UL>
  <code>wget https://raw.githubusercontent.com/llevier/vigrid/main/install/vigrid2-gns-install.sh</code><BR>
  <code>sudo sh vigrid2-gns-install.sh</code>, then provide the 'root' password.<BR>
  Nota: all script input/output is logged to a file into /tmp.
</UL>

Script will then flow installation steps:
<LI>First of all, sometimes the [BACKSPACE] key is a problem. Script will ask if you wish to set up/correct your [BACKSPACE] key</LI><BR>

<LI>Script will then launch a series of actions to prepare the server, asking you to define a timezone for the server</LI><BR>

<LI>You must then select which Vigrid architecture element you wish to install here.</LI><BR>

<LI>Then you must select the network design.</LI>
<UL>
  <LI>If you wish to manage that by yourself, no action will be taken at any network level (bonding, routing, firewalling...)</LI>
  <LI>Else Vigrid design will be installed, replacing the entire network configuration.<BR>The NIC used for network access for Ninternet0, using your detected configuration to the new format.<BR><B>It is advised to check at the configuration before rebooting.</B></LI>
</UL>
<BR>

<LI>From here, all software & configuration required by Vigrid will be installed/performed.
After a moment, you will be prompted to device if you wish to keep the default Qemu version or build a new one based on latest stable version available.<BR>
Building takes a moment but is advised since it will probably correct some bugs and bring new features, but it will definitely give 2 importants features: GPU access from VM via VirGL and many other CPU models for your VMs.
</LI><BR>

<LI>Still continuying the install of required packages, Vigrid will ask, if you decided to replace network configuration, to select the failover mecanism for the bond links. Vigrid network design creates single NIC bonds for each network interface. This permits to easily add other physical network interfaces if you wish to add redundancy or bandwith.</LI><BR>

<LI>Cyber Range design includes a VPN access to the infrastructure. That is mandatory to access Super Admin and Blue/Red LANs.<BR> 
Vigrid will install a safe configuration requiring to build certificates. To be able to do this, you will be asked to define 2 passwords:<BR>
<UL><LI>One for the Certificate Authority ()</LI>
<LI>One for the Client Certificate (PEM) VPN access</LI></UL>

<LI>On design relaying on central NAS, you will be prompted the 'root' password of the NAS so Vigrid can install a SSH key authentication it requires.</LI><BR>

<LI>Finally, depending on the install type, you will be prompted to do specific actions by the script.<BR>
Please read that carefully before rebooting the server.</LI><BR>

Once you are back to the user shell, you can take these action to finally reboot and start using the Vigrid element.<BR>
Default vigrid credentials for all accesses (GNS3, HTTPS, SSH, OpenVPN) is vigrid/vigrid.<BR>
Password of the 'gns3' user is defined into the ~gns3/.config/GNS3/gns3_server.conf file. It applies to the unix account as well.<BR>
Other users (root...) where not touched.<BR>
<BR>
Happy Vigrid usage ! Upon issues, please report to github.
<BR><BR>