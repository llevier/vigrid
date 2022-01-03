### Using Vigrid ###

<FONT SIZE=+2><B>Discovering the Control Tower</B></FONT><BR>

The Control Tower page brings you directly to Vigrid extensions working beside GNS3.<BR>
The following example illustrate with a Vigrid Cloning Farm composed of a Master (<code>vigrid-gns3</code>) and a Slave (<code>vigrid-GNS3slave</code>) with a <B>unique</B> project named <code>untitled</code>.<BR>
<IMG SRC="/docs/images/vigrid-control_tower.png"><BR>
Let's first discover the display:<BR>
<LI>Top left of page, the <A HREF="https://en.wikipedia.org/wiki/V%C3%ADgr%C3%AD%C3%B0r" TARGET="_vigrid">Vigrid God</A> logo from <A HREF="https://en.wikipedia.org/wiki/Emil_Doepler" TARGET="_painter">Emil Doepler's</A> painting and, at the right, the Vigrid architecture logo, as explained in documentation.</LI>
<LI>Below a serie of icons for specific actions:
<TABLE>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_refresh.png"></TD><TD>Refresh button, to regenerate the display</TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_uuid.png"></TD><TD>Button to toggle display of GNS3 UUID</TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_links.png"></TD><TD>Button to toggle Links between nodes. Once displayed, it is possible to change links behavior. <A HREF="/docs/vigrid-control_tower-links.md">Click me for more</A></TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_mon.png"></TD><TD>Button to call another page monitoring the Vigrid infrastructure (NAS, servers...). <A HREF="/docs/vigrid-control_tower-mon.md">Click me for more</A></TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_opened.png"></TD><TD>Button to display only opened projects</TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_active.png"></TD><TD>Button to display only active (at least a node running) projects</TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_gns3.png"></TD><TD>Button to display only running GNS3 hosts</TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_clone.png"></TD><TD>Button to call another page to clone a project on demand. <A HREF="/docs/vigrid-control_tower-clone.md">Click me for more</A></TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_clone_massive.png"></TD><TD>Button to call another page to massively clone a project.<A HREF="/docs/vigrid-control_tower-clone_massive.md">Click me for more</A></TD></TR>
</TABLE><BR>
Finally, the page automatically refreshes each 60 seconds, which can be changed.</LI>
<LI>Then it is project list display, offering for each column to 'preg filter' the display.<BR>
By default, all Vigrid hosts & projects will be displayed, which can be huge with big cloning farms where the same project will be present on each farm slave.
For each project, a serie of button is also available:<BR>
<TABLE>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_startstop.png"></TD><TD>Button to start or stop the entire project. Action is taken at each node level.</TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_onoff.png"></TD><TD>Button to open/close the project. It is not possible to start and get details of closed projects.</TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_snapshot.png"></TD><TD>Button to manage snapshots. Snapshots are required to rollback (restore) previous project configurations. They are also required to create clones. <A HREF="/docs/vigrid-control_tower-snapshot.md">Click me for more</A></TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_clone.png"></TD><TD>Button to call another page to clone this project on demand. <A HREF="/docs/vigrid-control_tower-clone.md">Click me for more</A></TD></TR>
<TR><TD ALIGN=CENTER><IMG SRC="/docs/images/vigrid-control_tower_clone_massive.png"></TD><TD>Button to call another page to industrially clone this project. <A HREF="/docs/vigrid-control_tower-clone_massive.md">Click me for more</A></TD></TR>
</TABLE></LI>
<BR>
 <A HREF="/docs/vigrid-control_tower-projects.md">Let's now focus on the Project display</A>