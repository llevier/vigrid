### Using Vigrid ###

<FONT SIZE=+2><B>Massively cloning a project</B></FONT><BR>

Massive/Industrial cloning purpose is totally different from ondemand cloning.<BR>
With ondemand clones, the spirit of the feature is to permit students/users to request a project copy, play with it for a while, then it will be terminated.<BR>
With the massive cloning, the spirit is to prepare the infrastructure for something more likely a competition or an exam where each participant or team must work on its private instance.<BR>
Accordingly, massive cloning is more for Vigrid infrastructures, so these many clones can be ran on different Vigrid Slaves to spread the load.<BR>
<BR>
<B>As with ondemand clones, a clone snapshot is mandatory.</B><BR>
<BR>
Arriving on the massive cloning page looks like below:<BR><BR>
<IMG SRC="/docs/images/vigrid-control_tower_clone_massive_page.png"><BR>
<BR>
As with ondemand cloning, some informations are required:<BR>
<LI><code>Target clone common name:</code> since all clones will come from a single one, they will all share the same name, just adding an integer at the end of this name, to define here.</LI>
<LI><code>Clones numbering, starting at:</code> will define the starting number in clone named (clone_01, clone_50...). Dont care about the integer format in the name, I'll manage for the best.</LI>
<LI><code>Wanted number of clones:</code> how many do you want Sir ?</LI>
<LI><code>email</code> since clones owner (single person) should be advised about how all clones will be created.</LI>
<BR>
Once filled, simply clicking on <code>REQUEST CLONING</code> to move to the page that will request another confirm to click on.<BR>
<BR>
When ondemand cloning is working asynchronously, pushing request to a daemon that will manage it, Massive Cloning is working realtime.<BR>
That is why, once you launched the cloning, display will become more 'technical' and long. Also, since massive cloning is performed at a very high speed, such a display will arrive and grow bigger very quickly !<BR>
Here is an extract for a request to clone <code>Cuntitled_</code> from 5, 2 times:<BR>
<code>Cloning in progress...</code><BR>
<code>Sanity checks...</code><BR>
<code>Running on vigrid-nas</code><BR>
<code>2021/09/09 13:36:09: Cloning untitled (a257aa5b-5b10-458f-88d1-cedbeece76c9) as Cuntitled_5...</code><BR>
<BR>
<code>Running on vigrid-nas...</code><BR>
<code>Project lowlevel cloning</code><BR>
<code>Source project UUID: a257aa5b-5b10-458f-88d1-cedbeece76c9@clonesource_20210909 (untitled) to clone as Cuntitled_5</code><BR>
<code>GNS3 projects dataset: Vstorage/GNS3/GNS3farm/GNS3/projects</code><BR>
<code>cloning project a257aa5b-5b10-458f-88d1-cedbeece76c9</code><BR>
<code>Phase 1: generating a target project free UUID...</code><BR>
<code>  Target project UUID for Cuntitled_5 will be e9653c5f-ca0d-4769-aceb-9b0928eb3b00</code><BR>
<code>Phase 2: Cloning project data tree...</code><BR>
<code>  Cloning (clone of master snapshot) project data directory...</code><BR>
<code>Phase 3: Reseting target project (UUID, MAC, consoles), delegated to project-lowlevel-reset...</code><BR>
<code>  GNS3 low level project reset program</code><BR>
<code>  GNS3 reseting project untitled (UUID=a257aa5b-5b10-458f-88d1-cedbeece76c9)</code><BR>
<code>2- Extracting all existing UUIDs (project itself included) from GNS3 projects directory...</code><BR>
<code>3- Extracting all UUIDs from project configuration file...</code><BR>
<code>4- managing console ports</code><BR>
<code>5- managing MAC addresses</code><BR>
<code>6- Finalizing target...</code><BR>
<code>Reseting untitled (a257aa5b-5b10-458f-88d1-cedbeece76c9) -> ### SUCCESS ###</code><BR>
<code>You should now send a SIGHUP to GNS3 server</code><BR>
<code>Cloning untitled (a257aa5b-5b10-458f-88d1-cedbeece76c9) as Cuntitled_5 -> ### SUCCESS ###</code><BR>
...[snip]...<BR>
<code>2021/09/09 13:36:15: Cloning untitled (a257aa5b-5b10-458f-88d1-cedbeece76c9) as Cuntitled_7...</code><BR>
<BR>
<code>Running on vigrid-nas...</code><BR>
<code>Project lowlevel cloning</code><BR>
<code>Source project UUID: a257aa5b-5b10-458f-88d1-cedbeece76c9@clonesource_20210909 (untitled) to clone as Cuntitled_7</code><BR>
<code>GNS3 projects dataset: Vstorage/GNS3/GNS3farm/GNS3/projects</code><BR>
<code>cloning project a257aa5b-5b10-458f-88d1-cedbeece76c9</code><BR>
<code>Phase 1: generating a target project free UUID...</code><BR>
<code>  Target project UUID for Cuntitled_7 will be 94e07a43-7d57-4eb5-a96b-7e543687a24b</code><BR>
<code>Phase 2: Cloning project data tree...</code><BR>
<code>  Cloning (clone of master snapshot) project data directory...</code><BR>
<code>Phase 3: Reseting target project (UUID, MAC, consoles), delegated to project-lowlevel-reset...</code><BR>
<code>  GNS3 low level project reset program</code><BR>
<code>  GNS3 reseting project untitled (UUID=a257aa5b-5b10-458f-88d1-cedbeece76c9)</code><BR>
<code>2- Extracting all existing UUIDs (project itself included) from GNS3 projects directory...</code><BR>
<code>3- Extracting all UUIDs from project configuration file...</code><BR>
<code>4- managing console ports</code><BR>
<code>5- managing MAC addresses</code><BR>
<code>6- Finalizing target...</code><BR>
<code>Reseting untitled (a257aa5b-5b10-458f-88d1-cedbeece76c9) -> ### SUCCESS ###</code><BR>
<code>You should now send a SIGHUP to GNS3 server</code><BR>
<code>Cloning untitled (a257aa5b-5b10-458f-88d1-cedbeece76c9) as Cuntitled_7 -> ### SUCCESS ###</code><BR>
<BR>
<code>Deployment done, dont forget:</code><BR>
<code>  1- To make gns3:gns3 owner of the project directory on target hosts</code><BR>
<code>  2- To SIGHUP all GNS3 servers...</code><BR>
<BR>
Once all these steps are performed successfully, as with all clonings, all GNS3 servers (Master & Slaves) should be restarted.<BR>
This action is not done automatically yet because some issue might happen, impact the restart of GNS3 servers.<BR>
Once GNS3 server 'reload' API will be available, cloning procedure will be updated.<BR>
Once servers are reloaded, all clones are available on all servers and ready to use.<BR>
<BR>
<FONT SIZE=+2><B>Return of experience about massive cloning</B></FONT><BR>
<LI>With massive cloning, except if you intend to provide a 'by user console access', you will probably rely on IP addresses to provide access to the nodes.<BR>
Vigrid also provide <A HREF="/docs/vigrid-cli.md">CLI commands</A> to help you easing such situations. For example, Vigrid is able to extract all MAC addresses in all project following the same naming pattern in a simple table usable to feed a DHCP server. In fact Vigrid can even provide the dhcpd.conf part.<BR>
Associating node to a specific IP, you became able to assign a project to a specific individual/team.</LI>
<LI>All these clones will have to be started, probably not too fast to avoid issues with a central NAS. Vigrid also provide a <A HREF="/docs/vigrid-cli.md">CLI command</A> to do that task without worrying.</LI>
