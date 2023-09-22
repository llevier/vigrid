### Using Vigrid ###

<FONT SIZE=+2><B>Vigrid CLI commands</B></FONT><BR>

As you understood, Vigrid actions are driven mostly by a WWW GUI and CLI commands. If some are not recommended to be used directly because they were not designed for such a use, some are very useful upon specific issues or needs.<BR>
<BR>
Here are the useful Vigrid CLI commands on Servers. They are in <code>/home/gns3/vigrid/bin</code>:<BR>
<TABLE>
<TR><TD  VALIGN=TOP><B>CLI Command</B></TD><TD  VALIGN=TOP><B>Parameters</B></TD><TD  VALIGN=TOP><B>Description</B></TD></TR>
<TR><TD  VALIGN=TOP><code>gns-launch</code></TD>
  <TD  VALIGN=TOP><code>-P&nbsp;ProjectName</code><BR><code>-p&nbsp;ProjectPause</code><BR><code>-n&nbsp;NodePause</code><BR><code>[&nbsp;-N&nbsp;NodeName&nbsp;]</code><BR><code>[&nbsp;-B&nbsp;BladesSpread&nbsp;]</code><BR><code>[&nbsp;-S&nbsp;0&nbsp;]</code><BR><code>[&nbsp;-A&nbsp;START|stop&nbsp;]</code></TD>
  <TD  VALIGN=TOP>It is common, after a massive cloning, to have to start (or stop) all these clones.<BR>This can be done 'by hand', clicking and clicking and clicking...or with this command.<BR>
  The project name must have a common part, specific node name can be provided. The important part if the delay between projects and/or nodes. Massive cloning relies on a central NAS and starting too quickly will generate a network overload slowing all starting VMs. If this overload is too heavy, then VM disks might be impacted, or VM failed to start. Specific delays (e.g 5 seconde between projects and 2 secondes between nodes) will spread this load, starting properly all projects.<BR>
  The BladeSpread parameter specific where to start which projects. Format is: "VigridServer1:Starting_number:Number_of_Projects_to_start VigridServer2:Starting_number:Number_of_Projects_to_start..."<BR>
  As example: "Server1:5:12 Server2:17:12" will start Project_05 to 12 on Server1, and Project_17 to 29 on Server2<BR>
  <code>-S [0|1]</code>is to launch simultaneously on different Vigrid Servers<BR></TD></TR>
<TR><TD  VALIGN=TOP><code>gns-power</code></TD><TD  VALIGN=TOP><code>-U&nbsp;username</code><BR><code>-P&nbsp;'password'</code><BR><code>-H&nbsp;'Host&nbsp;list'</code><BR><code>-A&nbsp;on|off|warm|reset</code></TD>
  <TD  VALIGN=TOP>This command, still in progress, has for purpose to power ON/OFF Vigrid servers. It is planned to detect Vigrid Servers load in order to power off unused ones, powerin on again upon detected need, to help saving this Planet.<BR>This command relies on the <code>VIGRID_POWER_</code> parameters suite in <code>Vigrid.conf</code></TD></TR>
<TR><TD  VALIGN=TOP><code>gns-run</code></TD><TD  VALIGN=TOP>gns-run</code><BR><code>[&nbsp;-H&nbsp;'Host&nbsp;list'&nbsp;]</code><BR><code>-A&nbsp;'shell&nbsp;command(s)'</code><BR><code>[&nbsp;-S&nbsp;]</code><BR></TD>
  <TD  VALIGN=TOP>This command will run a shell command (or a group of) on other (selected or not) Vigrid Servers. Very practical for actions such as updates.<BR>Relies on the <code>VIGRID_GNS_SLAVE_HOSTS</code> & <code>VIGRID_SSHKEY_GNS</code> parameters from <code>Vigrid.conf</code></TD></TR>
<TR><TD  VALIGN=TOP><code>node-grep-telnet</code></TD><TD  VALIGN=TOP><code>Host</code><BR><code>Port</code><BR><code>'Pattern'</code><BR><code>Action</code><BR><code>[&nbsp;-v&nbsp;]</code><BR><code>[&nbsp;-i&nbsp;]</code></TD>
  <TD  VALIGN=TOP>This command came from a bug during a CTF. We discovered too lately a specific VM, with telnet console, was failing. This command was created to launch a VM restart upon detection of the error message on the telnet console.<BR>Might save you one day :-)</TD></TR>
<TR><TD  VALIGN=TOP><code>project-control</code></TD><TD  VALIGN=TOP><code>-h&nbsp;Host</code><BR><code>-p&nbsp;ProjectName</code><BR><code>-a&nbsp;start|stop|estatus|status|open|close</code><BR><code>[&nbsp;-d&nbsp;NodePause_in_sec&nbsp;]</code><BR><code>[&nbsp;-n&nbsp;Specific_Node&nbsp;]</code></TD>
  <TD  VALIGN=TOP>A few line above, the <code>gns-launch</code> command is presented. This command is using <code>project-control</code> to start/stop projects on any Vigrid Server.</TD></TR>
<TR><TD  VALIGN=TOP><code>project-lowlevel-clone-industrial</code></TD><TD  VALIGN=TOP><B>Backoffice command:</B><BR><code>-p&nbsp;SourceProjectUUID</code><BR><code>-P&nbsp;SourceProjectName</code><BR><code>-z&nbsp;SnapshotMark</code><BR><code>-T&nbsp;TargetProjectPattern</code><BR><code>-s&nbsp;ProjectStartingNumber</code><BR><code>-q&nbsp;NumberOfClones</code><BR><code>-c&nbsp;ConsoleStartingRange</code><BR><code>-e&nbsp;ConsoleEndingRange</code><BR><code>[&nbsp;-b&nbsp;StorageRoot&nbsp;]</code><BR><code>[&nbsp;-r&nbsp;ReportFile&nbsp;]</TD>
  <TD  VALIGN=TOP>This command is used by the Massive Cloning page. It is just listed so you know this information.</TD></TR>
<TR><TD  VALIGN=TOP><code>project-lowlevel-clone-ZFS</code></TD><TD  VALIGN=TOP><code>-p&nbsp;Source_project_UUID</code><BR><code>-P&nbsp;'Source_project_name'</code><BR><code>-z&nbsp;'Snapshot_source_name'</code><BR><code>-T&nbsp;'Target_Clone_Name'</code><BR><code>-s&nbsp;Clone_starting_number</code><BR><code>-q&nbsp;Number_of_wanted_clones</code><BR><code>-c&nbsp;Console_starting_port</code><BR><code>-e&nbsp;Console_ending_port</code><BR><code>[&nbsp;-r&nbsp;Report_file&nbsp;]</code><BR><code>[&nbsp;-W&nbsp;]</code></TD>
  <TD  VALIGN=TOP>This command is used by the Massive Cloning page. It is just listed so you know this information.</TD></TR>
<TR><TD  VALIGN=TOP><code>project-lowlevel-merge</code></TD><TD  VALIGN=TOP><code>Project_Target</code><BR><code>Project_Source1</code><BR><code>Project_Source2</code><BR><code>Project_Source3</code><BR>...</TD>
  <TD  VALIGN=TOP>Purpose of this command is to merge GNS3 projects. For example, building a smart city would be a merge of grid (traffic, power...), hospital, schools...<BR>Still to do: detect node positions and recalculate them to avoid conflicting layering</TD></TR>
<TR><TD  VALIGN=TOP><code>project-lowlevel-reset</code></TD><TD  VALIGN=TOP><B>Backoffice command:</B></TD>
  <TD  VALIGN=TOP>The purpose of this command is to really reset an existing project. It is used on newly created clone.<BR>'Reset' means regenerate all UUID (but project's one itself) and MAC addresses, ensuring these are really unique on Vigrid Master Server/Infrastructure.</TD></TR>
<TR><TD  VALIGN=TOP><code>project-node</code></TD><TD  VALIGN=TOP><code>Project_name</code><BR><code>Node_name</code><BR><code>action</code></TD>
  <TD  VALIGN=TOP>This command was created after an issue on a specific node, part of a massively cloned project. With this command, you can take an action on any node regardless the Vigrid Server it runs on. Action can be <code>start</code>, <code>stop</code>, <code>status</code> or <code>console</code> (to connect telnet ones).</TD></TR>
<TR><TD  VALIGN=TOP><code>projectZFSsnapshot</code></TD><TD  VALIGN=TOP><B>Backoffice command:</B><BR></TD>
  <TD  VALIGN=TOP>This command is used by the Massive Cloning page. It is just listed so you know this information.</TD></TR>
<TR><TD  VALIGN=TOP><code>qemu-update</code></TD><TD  VALIGN=TOP>none</TD>
  <TD  VALIGN=TOP>This command is used to update the Qemu version on the server. It will show the existing one, detect the last stable on Internet and propose to update it.<BR>Updating means compiling it with all CPU and GPU support.<BR>Once updated, Qemu can be added '-device virtio-vga-gl -display egl-headless' flags so VM can access GPU (glxinfo will show 'virgl' as GPU).</TD></TR>
<TR><TD  VALIGN=TOP><code>vigrid-sshcheck</code></TD><TD  VALIGN=TOP><B>Backoffice command:</B><BR></TD>
  <TD  VALIGN=TOP>This command is used by the Massive Cloning page. It is just listed so you know this information.</TD></TR>
<TR><TD  VALIGN=TOP><code>vigrid-teleport</code></TD><TD  VALIGN=TOP></TD><TD  VALIGN=TOP></TD></TR>
</TABLE><BR>
<BR>
Vigrid CLI commands on the NAS. They are in <code>/Vstorage/GNS3/vigrid/bin-nas</code><BR>
<TABLE>
<TR><TD VALIGN=TOP>bin-nas/nas-load</TD><TD VALIGN=TOP><code>nas-load</code></TD><TD VALIGN=TOP>Display a monitoring page for the NAS.<BR>This includes:<LI>Vigrid storages</LI><LI>NAS CPU load (%)</LI><LI>NAS NFSd CPU status</LI><LI>List of Vigrid volumes</LI></TD></TR>
</TABLE><BR>
