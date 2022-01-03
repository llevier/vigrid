### Using Vigrid ###

<FONT SIZE=+2><B>Monitoring Vigrid infrastructure</B></FONT><BR>

This page has a single purpose: advise you about the load of the Vigrid infrastructure assets.<BR><BR>

The page automatically detects these assets and, using the SSH key authentication, get the values to display:<BR>
<IMG SRC="/docs/images/vigrid-control_tower_mon_page.png"><BR>
Nota: if you did not clicked on the button to display all hosts, including non-active, display will be restricted to the living ones.<BR>

<LI>NAS display:</LI>
<UL>
  <LI><B>Status</B>: it confirms the NAS is up & running</LI>
  <LI><B>SSH</B> can be either green or red. Being red, probably no further display will appear since SSH access failed.
  This can usually be repaired with a <code>cat /home/gns3/etc/id_NAS.pub | ssh <I>NAS_IPADDRESS</I>cat >>~/.ssh/authorized_keys</code></LI>
  <LI><B>IP address</B> display the IP address where NFS shares are exported</LI>
  <LI>The next 3 columns display the server load, completed by the 4th one idle load as a percentage.</LI>
  <LI>The <B>#cores</B> column is important. A Vigrid-NAS is a NFS server. If this server is not using most of cores available on the server, it will be slowed than possible. So if your server is slow despite a low load, you should check for the variable <code>RPCNFSDCOUNT</code> in the <code>/etc/default/nfs-kernel-server</code> file.</LI>
  <LI><B>RAM free</B> will display as it says. If your RAM is close to zero, then probably the next column will low too, that is bad.</LI>
  <LI><B>SWAP free</B>: on modern systems, when there is no more RAM, virtual memory is created on disk. It solves the missing but tremendously slow down the server. So if you see SWAP display turning to red, it is time to invest in RAM chips...</LI>
  <LI><B>Disk free/total</B>: this display fits with the Vigrid Architecture, explaining the different paths. It represents where Vigrid/GNS3 data is stored.</LI>
</UL>

<LI>GNS Hosts:</LI>
<UL>
  <LI><B>Server name</B>: being blue, it means this server is the master one.</LI>
  <LI><B>Status</B> represents the GNS3 server status. If light it not green, no project can run on this host.</LI>
  <LI><B>SSH</B> can be either green or red. Being red, probably no further display will appear since SSH access failed.
  This can usually be repaired with a <code>cat /home/gns3/etc/id_GNS3.pub | ssh <I>SERVER_IPADDRESS</I>cat >>~gns3/.ssh/authorized_keys</code></LI>
  <LI><B>Status</B> represents the GNS3 server status. If light it not green, no project can run on this host.</LI>
  <LI><B>IP address</B> display the IP address where GNS3, and so virtual network traffic, flows.</LI>
  <LI><B>TCP port</B> is GNS3's one.</LI>
  <LI>The next 3 columns display the server load, completed by the 4th one idle load as a percentage.</LI>
  <LI>The <B>#cores</B> column is important since it is used by your VM as vCPU.</LI>
  <LI><B>RAM free</B> will display as it says. If your RAM is close to zero, then probably the next column will low too, that is bad.</LI>
  <LI><B>SWAP free</B>: on modern systems, when there is no more RAM, virtual memory is created on disk. It solves the missing but tremendously slow down the server. So if you see SWAP display turning to red, it is time to invest in RAM chips...</LI>
  <LI><B>Disk free/total</B>: this display represents where Vigrid/GNS3 data is stored. If a Vigrid architecture relaying on a central Vigrid-NAS, values should match with the NAS.</LI>
</UL>
Vigrid Servers are ready to use multiple NAS, this is easy to configure on Vigrid Masters & Slaves.<BR>
But Vigrid NAS does not provide a realtime replication mecanism so this can be setup.<BR>
However, if you succeed doing this, I will be glad to integrate the code into Vigrid for common good.<BR>
