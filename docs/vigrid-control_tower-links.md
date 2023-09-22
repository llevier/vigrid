### Using Vigrid ###

<FONT SIZE=+2><B>Playing with links</B></FONT><BR>

On Vigrid Control Tower, if you clicked on the <code>Links</code> button, you may have noticed the nodes display, when node is running, is slightly different.<BR>
<IMG SRC="/docs/images/vigrid-control_tower_linksON.png"><BR>

Left of the IP address light in the <code>DHCP/ARP</code> column, a value appeared. It represents the network link of the node with another device.<BR>
Clicking on it will bring you to another page to control the link, as when you right on a GNS3 link and select <code>Packet filters</code>:<BR>
<IMG SRC="/docs/images/vigrid-control_tower_links_control.png"><BR>

In the first lines, this is only useful information:<BR>
<LI><B>Project</B>, <B>Link ID</B> & <B>Link type</B> are probably not interesting.</LI>
<LI><B>Bound to</B> is much better, indicating where this link is attached. That is always between 2 nodes</LI>
<LI>From <B>Specifications</B>, node can be modified while it runs:
<UL>
  <LI><B>Suspended</B> will permit to 'unplug' the link, as in the real world. Network interface will then change to DOWN</LI>
  <LI><B>Filter: corrupt</B> will randomly corrupt a packet. Define the packet corruption percentage.</LI>
  <LI><B>Filter: delay_latency</B> will adds latency and/or jitter. Define lattency & jitter in milliseconds.</LI>
  <LI><B>Filter: frequency_drop</B> will drop a packet every X packets. Define X here.</LI>
  <LI><B>Filter: packet_loss</B> will randomly drop a packet. Define the loss percentage.</LI>
  <LI><B>Filter: bpf</B> stands for <A HREF="https://en.wikipedia.org/wiki/Berkeley_Packet_Filter" TARGET="_bpf">Berkeley Packet Filter</A>. You can write an expression per line.<BR>
  There are many wikis explaing BPF syntax, <A HREF="https://biot.com/capstats/bpf.html" TARGET="_bpf">here is one</A></LI>
  </UL>
  <LI><B>CHANGE FILTERS</B> once you defined all fields you wish to.</LI>
</LI>
