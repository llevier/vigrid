### Vigrid framework installation ###

<FONT SIZE=+2><B>Vigrid NAS (Network Area Storage) installation</B></FONT><BR>

If you intend to work with a simple GNS3 server with Vigrid extensions, then setting up a dedicated NAS is not required. It will slow VMs globally since data will flow across network instead of using direct disk access drivers.
In such a design, Vigrid Server installation script will detect the additional disks and configure them to Vigrid standards.<BR>
If you intend to setup a farm (multiple servers), NAS installation is then mandatory.<BR><BR>

To launch Vigrid NAS installation, you must before:
<LI>Setup a Ubuntu LTS server, latest stable version</LI>
<UL>
  <LI>At least 16 GB (32GB advised to avoid Ubuntu update issues) are required for a flat root (/) filesystem</LI>
  <LI>root filesystem format (ext4...) is at your convenience</LI>
</UL>
<LI>Internet access must be available so vigrid can install more Ubuntu packages</LI>
<LI>Additional physical disks must be available. Vigrid will propose to configure them according to RAID standards</LI>
<LI>If you have an additional, even small, SSD disk, Vigrid will propose to use it as cache device.</LI>
<LI>If you prefer using hardware controller features for redundancy, that is not an issue for the install script that will then detect a single disk</LI>

<B>Nota: keep in mind all virtual machine data flows (hard drives etc) will be done over the network. Plan to use fast switches (10Gb/s) with on the Vigrid Farm. Of course, NIC bonding can also be done but it will then require more network physical interfaces on the servers.</B><BR>
<BR>

<FONT SIZE=+2><B>Installing a Vigrid NAS</B></FONT><BR>

<HR>
<FONT SIZE=+1><B>IMPORTANT POINT TO CONSIDER</B></FONT>:<BR>
In a Vigrid farm, virtual networks are communicating over a private network (Nsuperadmin0). Of course, you can setup your NAS in this LAN but it will then generate a Denial of Service risk, overloading the virtual network impacting Nsuperadmin0 bandwidth.<BR>
So it is advised to have your NAS on the Internet side of the Vigrid farm, normally less loaded.<BR>
It is planned to consider a dedicated NIC for NAS data flows in a future Vigrid version.
<HR>
Once your Ubuntu server is ready, logon and launch the below commands from your favorite shell:<BR>
<UL>
  <code>wget https://raw.githubusercontent.com/llevier/vigrid/main/install/vigrid1-nas-install.sh</code><BR>
  <code>sudo sh vigrid1-nas-install.sh</code>, then provide the 'root' password.<BR>
  Nota: all script input/output is logged to a file into /tmp.
</UL>

Script will then flow installation steps:
<LI>First of all, sometimes the [BACKSPACE] key is a problem. Script will ask if you wish to set up/correct your [BACKSPACE] key</LI><BR>

<LI>Script will then launch a series of actions to prepare the server, then you will be prompted to select the GNS3 data storage disk format, you must select ZFS between the below:</LI>
<UL>
  <LI><B>ZFS</B>: Currently that is the only working choice. ZFS is highly faster but enforced hierarchical snapshots, reducing Vigrid capabilities</LI>
  <LI><B>BTRfs</B>: For Vigrid usage, BTRfs provides more flexibility. However it is 10x slower than ZFS and Vigrid still needs its BTRfs scripts to be validated so BTRfs can be used</LI>
</UL>

<HR>
<FONT SIZE=+1><B>RAID: software or hardware ?</B></FONT><BR>
If you are using a server class RAID controller (with hardware cache, dedicated ASIC...) performance is better if the RAID hardware controller manages the disks directly. It also oftenly offers disk failure display (disk LED) and hot replacement, as well as automated array rebuilding.<BR>
Using hardware RAID array, you will simply select the single disk at Vigrid prompt, over RAID0 format.
<HR>

<LI>Once the filesystem format is selected, you will be prompted to select all physical disks (or partitions) to build a <A HREF="https://en.wikipedia.org/wiki/RAID" TARGET=_RAID>RAID</A> array. RAID provides failover and balanced load mecanisms, and so a safer storage.<BR>
<B>Nota</B>: Disk/partitions composing a RAID group must all have the same size.</LI>
<UL>
  <LI>Upon a ZFS filesystem format, you will also be prompted to define a disk/partition for ARC cache. ARC increase <B>readings</B> performance. It is advised to have ARC on SSD disks.</LI>
  <LI>Upon a ZFS filesystem format, you will also be prompted to define a disk/partition for ZIL cache. ZIL increase <B>writings</B> performance. It is advised to have ZIL on SSD disks.</LI>
</UL>
<LI>Once the RAID storage has been created, Vigrid will install its volumes & datasets, then it will install & enable the NFS service in charge of sharing Vigrid data to all farm servers.</LI>
<BR>
<LI>Install will then propose to add for you GNS3 servers you plan to have in the farm, asking their IP address and hostname, will create hosts entries, volumes & datasets for data sharing and add them to the existing ones.</LI>
<BR>
<LI>Finally, it is possible to launch a benchmark tool (fio) to evaluate the NAS R/W performance.</LI>
<BR>
Installation is then done, you can move to a <A HREF="/docs/vigrid2-gns-install.md">Vigrid Server install</A>.
<BR>

 
