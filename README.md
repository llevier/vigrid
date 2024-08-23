# Vigrid

<STRONG>Vigrid new release <A HREF="https://github.com/llevier/vigrid/tree/v1.2">v1.2, validated for Ubuntu 24LTS</A></STRONG>.

Vigrid is an extension to the GNS3 Hypervisor to turn it to a Cyber Range or a industrial training platform.

Once GNS3 is redesigned to Vigrid standards, trainings, Blue Team/Red Team or classical Capture The Flags will be possible through unlimited (upon hardware capabilities of servers) number of clones so each user or team can work on his own.

Virtual machines can work on many CPU (amd64/x86 of course, but also ARM, PowerPC, MIPS, Sparc etc).

A simple functionnal web server provides clientless access to virtual devices consoles (telnet or graphical) without keyboard issues and virtual machine or lab basic controls (power). Finally, through easy CLI commands (Web GUI TODO), virtual machine snaping shot, massive project cloning are available. RBAC is not yet provided because it will be available with GNS3v3.

Your server power is the limit :-)

Vigrid relies on standard designs: Standalone (historical gns3 design), Standalone with NAS, slaves with NAS, scalable with NAS
Vigrid covers all topics to have all features available, from start to end: NAS installation, GNS3 installation with Vigrid extensions

Name 'Vigrid' refers to the Ragnarok battleground, ultimate battle of the Gods (nordic mythology). 
You may also think it as 'V grid' (Virtualization Grid).

Vigrid extension is copyrighted to Laurent LEVIER, licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International

### Last updates ###
Major topics of Vigrid 1.2:
<ul><li>Ubuntu 24 LTS ready</li>
<ul><li>Multiple bugs corrected, due from packages & GNS3 updates.</li>
<ul><li>SSLh arguments are modified to reflect SSLh changes + corrected systemd config.</li>
<ul><li>OpenResty replaces NGinx.</li>
<ul><li>Vigrid to GNS3 authentication now directly performed by a NGinx LUA module.</li>

<BR><STRONG>IMPORTANT</STRONG>
GNS3 v3.0.0rc1 now provides RBAC. It has been tested RBAC works fine. With this, Vigrid can now also be a training environnment.
Soon to come:
<ul><li>OpenResty configured to relay JWT new GNS3 authentication.</li>
<ul><li>Vigrid will then directly use GNS3 authentication, no longer its own.</li>
<ul><li>To come soon: new Vigrid feature so a user can automatically clone a project + create ACL to make each clone of this project usable to other users, classical training operation.</li>

### QUICK INSTALL ###

First, install the last Ubuntu server LTS version on your hosts(s).
<BR><STRONG>Nota: install now validated until Ubuntu 24 LTS.</STRONG>

Recommendations:
<ul><li>Ubuntu:</li>
  <ul><li>32GB for root filesystem</li><li>Swap at your convenience</li></ul></ul>
<ul><li>GNS data storage:</li>
  <ul><li>Either on NAS or standalone servers: add more disk(s) (the bigger the better) for data and others for cache (R/W speed++). These disks for Vigrid storage will be detected and managed by the install script.</li></ul></ul>
<BR>

If you want to build an infrastructure <STRONG>(development version)</STRONG>, please first install NAS launching:
<UL>
  <code>wget https://raw.githubusercontent.com/llevier/vigrid/main/install/vigrid1-nas-install.sh</code><BR>
  <code>sudo sh vigrid1-nas-install.sh</code>, then provide the user password.<BR>
  Nota: all script input/output is logged to a file into /tmp..<BR><BR>
  <STRONG>Vigrid NAS design</STRONG>: the main ennemy of NAS is disk I/O. Roughly, it is considered a mecanical drive is able to perform 100 IOps. Accordingly, recommandations to have best NAS are:<BR>
  - Rely on hardware RAID (check possible performance issues related to ReadAhead & WriteBack).<BR>
  - Use RAID-1 or RAID-5, not RAID6 and more parity drives (loss of performance at writings).<BR>
  - Use as maximum of physical hard drives to spread the load, dont care about too much disk space.<BR>
  - Use SSD drives as cache, as with RAID, dont be afraid to have RAID-1 virtual drive as cache, spreading will raise IOps.<BR>
  - Disable all hardware optimisation mecanisms for cache drives (again ReadAhead & WriteBack).<BR>
  - Of course, obviously, if all hard drives are SSD, you will tremendously increase performance.<BR><BR>
  As an example: server with 2xe5-2620v3/128GB RAM, hardware RAID5 of 10x6TB HD + RAID1 of 2x400GB SSD as cache handled around 1000 32GB GNS3 VM simultaneously over a 10Gb/s network link.
</UL>

Else or to install Vigrid server(s) (standalone, scalable or cloning farm), launch:  
<UL>
  <code>wget https://raw.githubusercontent.com/llevier/vigrid/main/install/vigrid2-gns-install.sh</code><BR>
  <code>sudo sh vigrid2-gns-install.sh</code>, then provide the user password.<BR>
  Nota: all script input/output is logged to a file into /tmp.
</UL>

You can read the <A HREF="/docs/">documentation</A> for further explanations about designs, installation and usage.

### IMPORTANT ###
When Vigrid is in NAS mode, it means many projects/clones could be launched at a time.
One must keep in mind that a NAS has not infinite disk or network bandwidth.
Despite all my efforts, growing timeouts etc, if you launch too many nodes at a time with virtual hard drives stored on central NAS, network or disk saturation could lead to node failure or virtual machine disk I/O errors.
For now I have no other (yet) cooking recipe than checking each node load time, then put enough delays between project/nodes launches to avoid this situation.
With local data risk strong reduces, so I prepared Vigrid in a new design: Hybrid. In such a design, Vigrid keeps controlling centrally but projects are restricted to specific hosts where data is stored.
Of course, this risk can be manage also with better network, storage devices etc, as well as using different network interfaces and NASes.
Promissing study: ZFS over GlusterFS, itself sharing over NFS 4.2 (multipath). At the moment changes on ZFS are not propagated to GlusterFS :-(

### VERSIONS ###
For now, Vigrid is updated at high frequency and there is no starting version yet. Best method to be up to date is to regularly launch 'vigrid-update', considering this might generate short time issues.
A v1 version is planned ASAP so versionning can be properly performed.

### ISSUES ###
You can report your issues via github. For each issue, please at least provide the Vigrid Type (standalone, master etc) and the Vigrid network design (your concern, TINY of FULL cyber range).

### CONTRIBUTIONS ###
Vigrid layer is only developped by a single person on best effort on personal time. All contributors to add new features are welcome.  
Some most wanted features for a Cyber Range are in the TODO list: Cloning with docker nodes + PuppetMaster.  

Feel free to contact me.

### TODO with status ###
<TABLE>
  <TR><TD><B>Topic</B></TD>
  <TD><B>Status</B></TD></TR>
  <TR><TD>First GNS3v3 tests</TD>
  <TD>Postponed to new RBAC model on GNS3v3</TD></TR>
  <TR><TD>Error handling by command in install scripts (failing command can be rerun endlessly)</TD>
  <TD>Queued</TD></TR>
  <TR><TD>Change Control Tower display (project first column, then host) so start button automatically select best available host</TD>
  <TD>Queued</TD></TR>
  <TR><TD>Check code for security issues (input controls etc)</TD>
  <TD>Periodic action</TD></TR>
  <TR><TD>Test & validate 'projects with docker nodes' cloning</TD>
  <TD>Validated (limitations now known), queued</TD></TR>
  <TR><TD>Try to build a ZFS snapshot hierarchical tree to show dependencies</TD>
  <TD>Queued</TD></TR>
  <TR><TD>Add ZFS hold/release management on snapshot page</TD>
  <TD>Queued</TD></TR>
  <TR><TD>Concurrent/conflicting action detector</TD>
  <TD>Queued</TD></TR>
  <TR><TD>Add BTRFS management on servers (tested/validated but not implemented in Vigrid)</TD>
  <TD>DONE, extensive tests to perform</TD></TR>
  <TR><TD>Finish snaping/cloning at nodes level</TD>
  <TD>Validated with both FS, queued</TD></TR>
  <TR><TD>Add IPMI support for power control commands (only HP iLO for now)</TD>
  <TD>Queued</TD></TR>
  <TR><TD>Add automatic ecological savings (power on/off slaves according to needs)</TD>
  <TD>Validated, queued</TD></TR>
  <TR><TD>Add control tower URL to VIGRIDclones.list query (for mail sent to clone owner)</TD>
  <TD>Queued</TD></TR>
  <TR><TD>Move from PHP to Javascript code so browser can control slaves directly (via Vigrid hybrid mode) with much faster web display response time</TD>
  <TD>Hybrid mode validated, queued</TD></TR>
  <TR><TD>Move Vigrid NAS so it can satisfy requirements + provide parallel network sharing (major risk of projects launch failures)</TD>
  <TD>Study ongoing</TD></TR>
  <TR><TD>Developing a scenario automation software (PuppetMaster) to control discrete agents (Ghosts) into project so they can perform actions. For now, only concept of a central server controlling Ghost nodes into projects has been proven.</TD>
  <TD>Ongoing</TD></TR>
  <TR><TD>Creating a life simulation systems so network behaves as if real users would be working (mail, surf etc).</TD>
  <TD>Ongoing</TD></TR>
  <TR><TD>Add a shortcut on each Qemu node to 'qemu rebase' node disk (thus removing appliance image dependancy) or 'qemu commit' node disk to have appliance disk updated (thus failing all other nodes depending on it).</TD>
  <TD>Queued</TD></TR>
</TABLE>
