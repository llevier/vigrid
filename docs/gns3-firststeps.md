### Using Vigrid ###

<FONT SIZE=+2><B>Making GNS3 ready</B></FONT><BR>
<UL><LI>You must first install GNS3 heavy client. Please go to the <A HREF="https://www.gns3.com/software/download" TARGET="_gns3">GNS3 download page</A> and download the client.<BR>
Once done, launch the install, selecting only GNS3 client (removing everything else).</LI>
<IMG SRC="/docs/images/gns3-install.png">
<BR>
<LI>Once installed, start the GNS3 client. By default, GNS3 default installation is to run a local VM, but Vigrid will provide that service so it must be changed. For that:
<UL><LI>Go to the <code>Edit</code> Menu of GNS3, and select <code>Preferences</code>. A box will appear.<BR>
<IMG SRC="/docs/images/gns3-preferences1.png"><BR></LI>
<LI>Disable the local GNS3 VM and replace with HTTPS, Master IP Address, and Vigrid credentials:<BR>
<IMG SRC="/docs/images/gns3-preferences2.png"></LI></UL><BR>
<LI>You will probably be prompted to accept the certificate (home made, still you can use real one from your organisation, LetsEncrypt...) and then you will see GNS3 GUI</LI>
<BR>
<FONT SIZE=+2><B>First step with GNS3</B></FONT><BR>
<BR>
Now you are able to use GNS3, let's create a simple virtual network:
<LI>You entered into the <code>New Project</code> page. Validate clicking on <code>OK</code> to create the <code>untitled</code> project</LI>
<LI>From this blank page, click on the <code>Appliance</code> icon<IMG SRC="/docs/images/gns3-appliances.png"> to develop default ones</LI>
<LI>Drag & drop the <code>Cloud</code> icon <IMG SRC="/docs/images/gns3-cloud.png"> (not NAT) and a <code>VPCS</code> <IMG SRC="/docs/images/gns3-vpcs.png"> to the right side of the appliance list</LI>
<LI>Once these appliances are placed, create a link between them, clicking on the <code>Link</code> icon <IMG SRC="/docs/images/gns3-links.png">
<UL>
  <LI>Click on the <code>VPCS</code> and select the network interface</LI>
  <LI>Click on the <code>Cloud</code> and select <code>Nred_exposed0</code> interface</LI>
</UL>
<IMG SRC="/docs/images/gns3-untitled.png">
<LI>Now your objects are linked, you may start the <code>VPCS</code> appliance, right clicking on it<BR>
<IMG SRC="/docs/images/gns3-untitled-start.png"><BR>
Then select <code>Console</code> to have its local display in a new window. You may then enter <code>ip dhcp</code> to get an IP address</LI>
<BR>
This will be enough for our purpose. Please go to <A HREF="https://docs.gns3.com/docs/" TARGET="_gns3">GNS3 Documentation</A> to learn how to use GNS3.</UL><BR>
