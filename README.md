# Vigrid
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

### QUICK INSTALL ###

First, install the last Ubuntu server LTS version on your hosts(s).

Recommendations:
<ul><li>Ubuntu:</li>
  <ul><li>32GB for root filesystem</li><li>Swap at your convenience</li></ul></ul>
<ul><li>GNS data storage:</li>
  <ul><li>Either on NAS or standalone servers: add more disk(s) (the bigger the better) for data and others for cache (R/W speed++). These disks for Vigrid storage will be detected and managed by the install script.</li></ul></ul>
<BR>

If you want to build an infrastructure, please first install NAS launching:
<UL>
  <code>wget https://raw.githubusercontent.com/llevier/vigrid/main/install/vigrid1-nas-install.sh</code><BR>
  <code>sudo sh vigrid1-nas-install.sh</code>, then provide the user password.<BR>
  Nota: all script input/output is logged to a file into /tmp.
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
For now I have no other cooking recipe than checking each node load time, then put enough delays between project/nodes launches to avoid this situation.
With local data risk strong reduces, so I prepared Vigrid in a new design: Hybrid. In such a design, Vigrid keeps controlling centrally but projects are restricted to specific hosts where data is stored.
Of course, this risk can be manage also with better network, storage devices etc, as well as using different network interfaces and NASes.

### VERSIONS ###
For now, Vigrid is updated at high frequency and there is no starting version yet. Best method to be up to date is to regularly launch 'vigrid-update', considering this might generate short time issues.
A v1 version is planned ASAP so versionning can be properly performed.

### ISSUES ###
You can report your issues via github. For each issue, please at least provide the Vigrid Type (standalone, master etc) and the Vigrid network design (your concern, TINY of FULL cyber range).

### CONTRIBUTIONS ###
Vigrid layer is only developped by a single person on best effort. All contributors to add new features are welcome.  
Some most wanted features for a Cyber Range are in the TODO list: Cloning with docker nodes + PuppetMaster.  

Feel free to contact me.

### TODO ###
<ul>
<li>Error handling by command in install scripts (failing command can be rerun endlessly)</li>
<li>Add BTRfs management on servers</li>
<li>Change Control Tower display (project first column, then host) so start button automatically select best available host</li>
<li>Check code for security issues (input controls etc)</li>
<li>Test & validate 'projects with docker nodes' cloning</li>
<li>Try to build a ZFS snapshot hierarchical tree to show dependencies</li>
<li>Add ZFS hold/release management to snapshot page</li>
<li>Concurrent/conflicting action detector</li>
<li>Try to make BTRfs much faster</li>
<li>Finish snaping/cloning at nodes level</li>
<li>eszm installed as well (in control_tower_mon)</li>
<li>Add IPMI support for power control commands (only HP iLO for now)</li>
<li>Add automatic ecological savings (power on/off slaves according to needs)</li>
<li>NAS load (CPU/NFS/ZFS/BTRfs) as daemon to reduce time to get infos via ssh</li>
<li>OpenVPN client restricted access for BlueAdmin, RedAdmin, BlueExposed & RedExposed</li>
<li>OpenVPN LANtoLAN restricted access for BlueExposed & RedExposed</li>
<li>Add control tower URL to VIGRIDclones.list query (for mail sent to clone owner)</li>
<li>If GNS3v3 cant have RBAC in reasonable delay, integrate https://github.com/srieger1/gns3-proxy into Vigrid authentication</li>
<li>Move from PHP to Javascript code so browser can control slaves directly (via Vigrid hybrid mode) with much faster web display response time</li>
<li>Developing a scenario automation software (PuppetMaster) to control discrete agents (Ghosts) into project so they can perform actions. For now, only concept of a central server driving ghost nodes into projects has been proven.</li>
<li>Creating a life simulation systems so network behaves as if real users would be working (mail, surf etc).</li>
</ul>