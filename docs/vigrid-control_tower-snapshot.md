### Using Vigrid ###

<FONT SIZE=+2><B>Projects snapshots</B></FONT><BR>

Snapshots are a major enhancement provided by Vigrid to GNS3/Qemu.<BR>
Previously, snapshot were provided by Qemu only, and based on the overlay filesystem design. It means the snapshot is a difference between a previous file and a current one. Upon an unexpected loss or change of this previous file and all is lost. Added to this, snapshots were associated with a single file and so filesystem/NFS read cache.<BR>

With Vigrid, snapshots are performed at the filesystem level, turning it to an atomic operation (immediate), without data consumption, and upon hierarchical tree a strong warn about consequences to destroy a snapshot.<BR>
Finally, associated with filesystem cloning capabilities, snapshots offered to massively clone with the same benefits (instantaneous without disk cost) also providing stronger read cache capabilities since clones start data is the same disks blocks.<BR>

<FONT SIZE=+1><B>Let's see how to deal with Vigrid Snapshots</B></FONT><BR>
<BR>
The snapshot page looks like:<BR>
<BR>
<IMG SRC="/docs/images/vigrid-control_tower_snapshot_page.png"><BR>
Revelant information are:
<LI><B>Project name, host name and nodes</B>, just to be sure you are on the good ones.</LI>
<LI><B>Project snapshots</B> will show the status about snapshots and list of existing ones, even not from Vigrid</LI>
<BR>
<FONT SIZE=+1><B>Understanding Vigrid snapshot steps</B></FONT><BR>
<BR>
To be 'snapshotable', a GNS3 project must lie into a specific format at the filesystem level. Since GNS3 directly addresses the filesystem as any normal program, using classical <code>mkdir()</code>, <code>rmdir()</code>, <code>unlink()</code> system calls, Vigrid functions must be managed by the Control Tower. This explains why, arriving on the snapshot page, you might see a project is not ready for snapshots.<BR>
<BR>
Upon such a situation, Vigrid will propose as action: <code>Converting project ?</code>. At this step, project data must be copied to the new format, so it is best to do this action at the project creation since project will probably grow with its age. The bigger project is, the more risk of a failure to happen.<BR>
For each action, <code>CONFIRM</code> is required:<BR>
<IMG SRC="/docs/images/vigrid-control_tower_snapshot_convert.png"><BR>
Once confirmed, this action might take a while...be patient... to produce a similar display:<BR>
<code><B>Requested action:</B></code><BR>
<code>Convert project untitled (a257aa5b-5b10-458f-88d1-cedbeece76c9) to dataset on host vigrid-gns3</code><BR>
<code><B>Taking action...</B></code><BR>
<code>Stopping project & closing project, required for conversion, add clone mark or rolling back...</code><BR>
<code>Closing project...</code><BR>
<code>Conversion of project a257aa5b-5b10-458f-88d1-cedbeece76c9 starting...</code><BR>
<code>Renaming /Vstorage/GNS3/GNS3farm/GNS3/projects/a257aa5b-5b10-458f-88d1-cedbeece76c9 to .old done</code><BR>
<code>Creating dataset 'Vstorage/GNS3/GNS3farm/GNS3/projects/a257aa5b-5b10-458f-88d1-cedbeece76c9'</code><BR>
<code>Vstorage/GNS3/GNS3farm/GNS3/projects/a257aa5b-5b10-458f-88d1-cedbeece76c9 dataset created</code><BR>
<BR>
Changing the Projects display to:<BR>
<IMG SRC="/docs/images/vigrid-control_tower_snapshot_ready.png"><BR>
where <code>Project snapshots</code> is now ready, showing no snapshot exists yet.<BR>
<BR>
<FONT SIZE=+1><B>Understanding Vigrid Snapshots</B></FONT><BR>
<BR>
In Vigrid, there can be 2 types of snapshot: for <code>history</code> or for <code>clone</code>.<BR>
<LI><B>History snapshot</B> is meant for rolling back project in previous versions. Depending on the Vigrid Storage Mode (ZFS/BTRfs), there might be hierarchical links, meaning if you rollback to an old snapshots, more recent ones will be <B>destroyed</B>.</LI>
<LI><B>Clone snapshot</B> is to be created when you intend to clone a project, whether ondemand or massively.</LI>
<BR>
<FONT SIZE=+1><B>Taking action</B></FONT><BR>
<BR>
To create or delete snapshots, it is very simple, just use the ad hoc menu to:
<LI><code>Create a clone snapshot</code> will create a snapshot to be used as a clone source</LI>
<LI><code>Destroy a clone snapshot</code> will delete an existing clone source</LI>
<LI><code>Create a history snapshot</code> will create a snapshot to rollback at a previous version</LI>
<LI><code>Delete a history snapshot</code>will delete an existing history snapshot</LI>
<LI><code>Change a snapshot (History <-> Clone)</code> will change a snapshot from a type to the other</LI>
<BR>
Upon a <code>Other source</code> snapshot type is shown, it means this snapshot was created out of Vigrid standards. It still exists, could be destroyed upon a rollback, but it is not accessible from Vigrid menus.<BR>
<BR>
<B>Notas:</B><BR>
<LI>A snapshot being a 'photo' of the VM's filesystem, the entire project should have been powered off properly when the snapshot is taken</LI>
<LI>Since snapshot are hierarchically linked, it is a good practice to provide a timestamp (YYYYMMDD_HHMMSS) in the snapshot name.</LI>
<BR>
