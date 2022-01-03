### Using Vigrid ###

<FONT SIZE=+2><B>Controlling projects</B></FONT><BR>

By default, Vigrid prefers closed projects because it consumes less GNS3 resources and it starts much faster.<BR><BR>
<IMG SRC="/docs/images/vigrid-control_tower-short.png"><BR>
Clicking on the <code>Host name</code> will restrict the display to only that host<BR>
Clicking on the <code>Project name</code> will restrict the display to only that project<BR>
<BR>
To be able to play with a project, it must first be opened, then started. So your first action is to open the project pushing the appropriate button presented in the <A HREF="/docs/vigrid-control_tower.md">Control Tower page</A>. This will change the Project display to the below, revealing the nodes:<BR>
<IMG SRC="/docs/images/vigrid-control_tower_Pstarted.png"><BR>
New information are provided:
<LI><B>Node name</B> (UUID column is possible clicking on the <code>UUID</code> button)</LI>
<LI><B>Console</B> (physical screen of the virtual node) IP address, protocol (either none, telnet or VNC) and port without a required heavy client.</LI>
<LI><B>Status</B> (either <code>started</code> or <code>stopped</code>). Clicking on the status will generate a start/stop request to turn to the opposite status.</LI>
<LI><B>DHCP/ARP</B>: Vigrid being autonomous, it includes its own DHCP server per LAN. Upon a given IP address, it will be shown here</LI>
<LI>If you click on the <code>Links</code> button, another coloum will appear. We will see that <A HREF="/docs/vigrid-control_tower-links.md">here</A>.</LI><BR>
From here, you can either start the whole project, clicking on the <code>Start</code> button on the left, or click to start a specific node on the <code>stopped</code> link in the <B>Status</B> column.<BR>
<BR>
Once your started a node, display changes again to reveal new infos:
<IMG SRC="/docs/images/vigrid-control_tower_Nrunning.png"><BR>
<LI><B>Node name</B> changed to display the number of cores & sockets of the Qemu node.</LI>
<LI><B>Console</B> is now clickable. Clicking on it will open a new WWW page to the node physical console (either telnet or VNC).<BR>
Nota: there should be no key mapping issue with Vigrid, as far as your VM keymap matches your keyboard of course</LI>
<LI><B>DHCP/ARP</B>: if the VM is attached to a *real* network (<code>Nsuperadmin0</code>, <code>Nblue_admin0</code>, <code>Nred_admin0</code>, <code>Nblue_exposed0</code> or <code>Nred_exposed0</code>), there should be a green light with an IP address at its right. That is the IP address of the node</LI>
