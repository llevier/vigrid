### Using Vigrid ###

Once your Vigrid infrastructure (NAS, server(s), switches...) is ready, you can start playing with it.

First of all, please notice HTTPS port (443/TCP) and the overall entry point to Vigrid.<BR>
It offers SSH to Master server, VPN access to the infrastructure, GNS3 access as well as Vigrid web user interface.<BR>
<BR>
In any case, default credentials are <code>vigrid</code> as username, and <code>vigrid</code> as password.<BR>
Credentials are stored on Vigrid Master Server into the file <code>/home/gns3/etc/vigrid-passwd</code> in PLAIN format:<BR>
<code>vigrid:{PLAIN}vigrid</code>
<BR>
Credentials for <code>gns3</code> user, generated during installation, are also stored in this file. You may of course add your own accounts.
<BR>

As a start, let's connect to the Vigrid Master Server over HTTPS, Vigrid will display a simple page to introduce itself, proposing to move to the Control Tower page. This will confirm Vigrid looks ready.<BR>
<BR>
However, what's the use of a Control Tower if there is nothing to control so, as a second step, you must start playing with GNS3 so there is at least a simple project to play with.<BR>

Here is the summary of 'must read' to be autonomous with Vigrid:<BR>
<LI><A HREF="/docs/gns3-firststeps.md">Making GNS3 ready</A></LI>
<LI><A HREF="/docs/vigrid-control_tower.md">Discovering Vigrid Control Tower</A></LI>
<LI><A HREF="/docs/vigrid-control_tower-mon.md">The hosts monitoring page</A></LI>
<LI><A HREF="/docs/vigrid-control_tower-projects.md">Controlling projects</A></LI>
<LI><A HREF="/docs/vigrid-control_tower-links.md">Playing with links</A></LI>
<LI><A HREF="/docs/vigrid-control_tower-snapshot.md">Snaping shot projects</A></LI>
<LI><A HREF="/docs/vigrid-control_tower-clone.md">Cloning a project on demand</A></LI>
<LI><A HREF="/docs/vigrid-control_tower-clone_massive.md">Massively cloning a project</A></LI>
<LI><A HREF="/docs/vigrid-cli.md">Vigrid CLI commands</A></LI>

<BR>
<FONT SIZE=+2><B>Vigrid infrastructure services:</B></FONT><BR>
<LI><A HREF="/docs/vigrid-openvpn-u2l.md">Seamless USERtoLAN VPN access to Vigrid</A></LI>
<LI><A HREF="/docs/vigrid-openvpn-l2l.md">Seamless LANtoLAN VPN access to Vigrid</A></LI>


