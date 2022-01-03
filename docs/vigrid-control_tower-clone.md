### Using Vigrid ###

<FONT SIZE=+2><B>Cloning projects on demand</B></FONT><BR>

Vigrid can also be used as a training center for individuals. In such uses, virtual networks & devices are oftenly created and made available for students. Here we will consider training as any exercice where each student must have its own virtual playground, whatever the use (training, capture the flag etc).<BR>
The principe of the Vigrid Clone is precisely to solve such needs. Once the virtual network is ready, anyone can request to have his/her clone. Clone is personal, user can do anything with it, and will be terminated once it reaches its lifetime.<BR>
<BR>
<FONT SIZE=+1><B>Steps to create ondemand clones</B></FONT><BR>
<BR>
Quickly summarized:
<LI>Create a virtual network for the training</LI>
<LI>Once tested, power it off properly</LI>
<LI>Mark it for cloning, see <A HREF="/docs/install/vigrid-control_tower-snapshot.md">Snaping shot projects</A></LI>
<LI>Publish the availability of the project ondemand to users</LI>
<BR>
<FONT SIZE=+1><B>How ondemand cloning works ?</B></FONT><BR>
<BR>
Arriving on the cloning page, available projects are listed:<BR>
<IMG SRC="/docs/images/vigrid-control_tower_clone_page.png"><BR>
User must just provide some information:<BR>
<LI><code>Clone max. life</code> will be the number of minutes the clone will live.</LI>
<LI><code>email</code> since user should be advised about how to access it the clone once it is ready.</LI>
<LI><code>Password</code> to ensure access will remain private. The access control is performed at the 'clone control tower' web page level, not at GNS3 level. So any user accessing the normal control tower will be able to access the clone.</LI>
<BR>
Once filled, simply clicking on <code>REQUEST CLONING</code> will put the request in the queue and as soon as possible (oftenly that is immediate), the cloning request will start and an email will be sent to the user.<BR>
<BR>
Into the mail are the clone details and a link to the clone Control Tower (auth'd access) to reach all clones related to that user/mail.<BR>
5 minutes before the clone end of life, the user will receive another email to warn about the clone death to come.<BR>
At the given time, clone is terminated, automatically closing & killing accesses.<BR>
<BR>
This is managed by a daemon and a SQL database. So it is easy to create a page to provide more life or other features.<BR>
<BR>