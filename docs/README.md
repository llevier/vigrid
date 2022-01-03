### Vigrid Documentation ###

Vigrid is a opensource and free (for non commercial use) Cyber Range framework.<BR>
However, it is not limited to such a use. Vigrid also fits into engineering tests, trainings, awarenesses, virtual network setup for any use (data collect, tests etc).

<FONT SIZE=+2><B>What is a Cyber Range ?</B></FONT><BR>
To explain it simply, soldiers needs to train in order to be the most efficient during war times. They rely on training grounds where they can use *real* weapons of any kind, even sometimes with *real* ammo.
A Cyber Range is exactly the same...in the computer world.

A Cyber Range offers to build virtual networks with the same operating systems, devices, vendor solution etc existing in the real world. The only difference is these are in real virtual machines. Once such a network is built, it can be used the same as if it was a real physical network.
The main difference is a virtual network can be rewind so the same training can start over and over again until learnt...without being forced to install everything again.

<FONT SIZE=+2><B>Cyber Range network designs</B></FONT><BR>
It is a standard with Cyber Ranges, as well as warfare, to use the Blue Team / Red Team designs.
In warfare, Blues must take the flag from Reds and vice-versa.
In Cyber Ranges, Reds are oftenly the attackers and Blues must defend the place...still being capable to attack Reds if they can.

<BR><FONT SIZE=+2><B>What is Vigrid in all this ?</B></FONT><BR>
Vigrid is an extension to the famous <A HREF="https://www.gns.com">GNS3 software</A>. GNS3 is using emulators such as Qemu or docker, adding its own tools to virtualize the network into a easy to use orchestrating solution, including heavy client to build virtual networks, appliances etc.<BR>
Vigrid is only completing/extending GNS3 to provide a much more efficient way other capacilities such as ondemand or industrial cloning, framework designs, cyber range network design ready, remote access...
Once Vigrid is installed, GNS3 capabilites are demultiplicated:
<LI>Multiple CPU emulations over Qemu (see <A HREF="https://qemu-project.gitlab.io/qemu/system/targets.html">Qemu CPU list</A>)</LI>
<LI>GPU access on Qemu VMs via <A HREF="https://virgil3d.github.io/">VirGL</A></LI>
<LI>Cyber Range ready design (with or without Blue/Red admin networks)</LI>
<LI>Virtual networks attachable to physical networks</LI>
<LI>Virtual networks isolated from each other (except if attached to the same physical network)</LI>
<LI>Extended functions such as:</LI>
<UL>
  <LI>NAS ready (or not) architecture design</LI>
  <LI>VPN seamless access (USERtoLAN and LANtoLAN)</LI>
  <LI>Vigrid network design automatically build bonding ready network links</LI>
  <LI>Easy project ondemand or industrial cloning without time & storage cost</LI>
  <LI>Easy project snapshot & rollback</LI>
  <LI>Easy project balanced launches (over any number of Vigrid slaves)</LI>
  <LI>Easy project/nodes launch & controls over an easy to use WWW interface</LI>
</UL>
<LI>Future: scenario automation to control agents (*nix, windows...) hosted into virtual networks</LI>
<LI>Future: RBAC (Role Based Access Control) to come with GNS3 v3</LI>

<BR><FONT SIZE=+2><B>Enough bla bla, let's go to the real world now</B></FONT><BR>
To be able to install Vigrid, you must first understand the possible architectures.<BR>
<LI>Vigrid can be standalone without a NAS (Network Attached Storage). That is the simplest design. Vigrid will then configure the server to have all its features.</LI>
<LI>Vigrid can also use a NAS, either being a standalone server, or part of a Farm, either for cloning or scalability.</LI>
<LI>Vigrid can install Cyber Range network design (with or without Blue/Red Admin), or let you manage this part.</LI>
<BR>
<TABLE>
  <TR>
    <TD><B>Vigrid Types</B></TD>
    <TD><B>Vigrid Logo</B></TD>
    <TD><B>Pros</B></TD>
    <TD><B>Cons</B></TD>
  </TR>
  <TR>
    <TD>Vigrid standalone server<BR>without NAS</TD>
    <TD><IMG SRC="https://github.com/llevier/vigrid/blob/7cb4d17c8c960da5a0cc1f7aed365c5f008ec149/www/site/images/vigrid_type1.png" WIDTH=80></TD>
    <TD VALIGN=TOP>
      <LI>Easy+quick install via installation script</LI>
      <LI>Still Vigrid features (CPU/GPU, snapshot, cloning...) are available</LI>
      <LI>Auto detection of available physical drives for Vigrid secure storage</LI>
      <LI>Vigrid Cyber Range network design possible</LI>
    </TD>
    <TD VALIGN=TOP>
      <LI>Can't be part of a farm that requires central storage</LI>
    </TD>
  </TR>
  <TR>
    <TD>Vigrid standalone server<BR>with NAS</TD>
    <TD><IMG SRC="https://github.com/llevier/vigrid/blob/8e59343b2b8f39ddf2730d9e6b11905798a68901/www/site/images/vigrid_type2.png" WIDTH=80></TD>
    <TD VALIGN=TOP>
      <LI>Easy+quick NAS & server install via installation script</LI>
      <LI>Auto detection of available physical drives for Vigrid NAS secure storage</LI>
      <LI>Same features as Vigrid standalone server without NAS</LI>
      <LI>Plus the possibility to change into a Vigrid Master Server to control a Farm (Cloning or Scalable)</LI>
    </TD>
    <TD VALIGN=TOP>
      <LI>Vigrid NAS must be installed (much better). However, other NAS might fit if SSH root access over SSH key is possible and NAS is using either BTRfs or ZFS over NFS.</LI>
      <LI>Server cant be standalone anymore. Network infrastructure (switch etc) is required.</LI>
    </TD>
  </TR>
  <TR>
    <TD>Vigrid Master server<BR>with NAS</TD>
    <TD><IMG SRC="https://github.com/llevier/vigrid/blob/6d324ea1939e8edfc88e642d63c07e8df0b25101/www/site/images/vigrid_type3.png" WIDTH=80></TD>
    <TD VALIGN=TOP>
      <LI>Easy+quick NAS & server install via installation script</LI>
      <LI>Auto detection of available physical drives for Vigrid NAS secure storage</LI>
      <LI>Same features as Vigrid standalone server without NAS</LI>
      <LI>Master server gateway to access all Vigrid Slave Servers (either for cloning or scalability)</LI>
      <LI>Unlimited number of Slaves can be controlled</LI>
    </TD>
    <TD VALIGN=TOP>
      <LI>Vigrid NAS must be installed (much better). However, other NAS might fit if SSH root access over SSH key is possible and NAS is using either BTRfs or ZFS over NFS.</LI>
      <LI>Server cant be standalone anymore. Network infrastructure (switch etc) is required.</LI>
    </TD>
  </TR>
  <TR>
    <TD>Vigrid Slave<BR>(with NAS)</TD>
    <TD></TD>
    <TD VALIGN=TOP>
      <LI>Cloning Farm: provide more CPU/memory to the Farm, permitting to run more clones at a time</LI>
      <LI>Scalable Farm: provide more CPU/memory to extend even more a big virtual network(s) project</LI>
    </TD>
    <TD VALIGN=TOP>
    </TD>
  </TR>
</TABLE>
<BR>
<TABLE>
  <TR>
    <TD><B>Vigrid Network Designs</B></TD>
    <TD><B>Pros</B></TD>
    <TD><B>Cons</B></TD>
  </TR>
  <TR>
    <TD>Vigrid TINY Cyber Range</TD>
    <TD VALIGN=TOP>
      <LI>Network ready design. NICs are detected and configured, Firewall rules installed, VPN access provided.</LI>
      <LI>Bond ready network. Upon other NIC available, load balance, failover... can be setup easily</LI>
      <LI>DHCP server for VM linked to Vigrid Control Tower</LI>
      <LI>NAS can be attached to WAN side (advised) for reduced DoS risk</LI>
    </TD>
    <TD VALIGN=TOP>
      <LI>Require 4 physical network interfaces: Internet, Admin, Blue & Red</LI>
    </TD>
  </TR>
  <TR>
    <TD>Vigrid FULL Cyber Range</TD>
    <TD VALIGN=TOP>
      <LI>Network ready design. NICs are detected and configured, Firewall rules installed, VPN access provided.</LI>
      <LI>Bond ready network. Upon other NIC available, load balance, failover... can be setup easily</LI>
      <LI>DHCP server for VM linked to Vigrid Control Tower</LI>
      <LI>NAS can be attached to WAN side (advised) for reduced DoS risk</LI>
    </TD>
    <TD VALIGN=TOP>
      <LI>Require 6 physical network interfaces: Internet, Admin, Blue Admin, Red Admin, Blue & Red</LI>
    </TD>
  </TR>
  <TR>
    <TD>No Vigrid network design</TD>
    <TD VALIGN=TOP>
      <LI>DHCP Server proposed (yours to configure) during install</LI>
    </TD>
    <TD VALIGN=TOP>
      <LI>Your job, your limits, your issues :-)</LI>
    </TD>
  </TR>
</TABLE>
<BR><FONT SIZE=+2><B>Vigrid Cyber Range Security Policy</B></FONT><BR>
<IMG SRC="/docs/images/Vigrid-CR-policy.png">

### Installation ###

<A HREF="/docs/vigrid1-nas-install.md">Network Attached Storage installation</A>, before servers.<BR>
<A HREF="/docs/vigrid2-gns-install.md">Vigrid Server (any type or network design)</A>.<BR>

### Usage ###

<A HREF="/docs/vigrid-usage.md">How to use Vigrid</A><BR>
