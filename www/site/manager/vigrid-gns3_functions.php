<?php
#################################################################################################################################
##
## This material is part of VIGRID extensions to GNS3 for Trainings & CyberRange designs
##
## (c) Laurent LEVIER for script, designs and technical actions, https://github.com/llevier/
## LICENCE: Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA)
##
## Each dependancies (c) to their respective owners
##
##################################################################################################################################
	// Vigrid functions
  
  function VIGRIDheader($header)
  {
    $hostname=gethostname();
    
    $header_meta="vigrid_".strtolower(preg_replace("/ /","_",$header));
    
    ?><html><head>
    <meta name="<?php print $header_meta; ?>" content="noindex,nofollow">
    <title><?php print $hostname." ".$header; ?></title>
    </head>
    <style type="text/css">
      form { display:inline; margin:0px; padding:0px; }

      /* Tooltip container */
      .tooltip {
        position: relative;
        display: inline-block;
      }

      /* Tooltip text */
      .tooltip .tooltiptext_onit {
        visibility: hidden;
        width: 120px;
        background-color: yellow;
        color: #0006ff;
        font-weight: bold;
        text-align: center;
        padding: 5px 0;
        border-radius: 6px;
       
        position: absolute;
        z-index: 1;
        bottom: 50%;
        left: 50%;
        margin-left: 0px;
      }

      /* Tooltip text */
      .tooltip .tooltiptext_above {
        visibility: hidden;
        width: 120px;
        background-color: yellow;
        color: #0006ff;
        font-weight: bold;
        text-align: center;
        padding: 5px 0;
        border-radius: 6px;
       
        position: absolute;
        z-index: 1;
        bottom: 100%;
        left: 50%;
        margin-left: -60px;
      }

      /* Tooltip text */
      .tooltip .tooltiptext_below {
        visibility: hidden;
        width: 120px;
        background-color: yellow;
        color: #0006ff;
        font-weight: bold;
        text-align: center;
        padding: 5px 0;
        border-radius: 6px;
       
        position: absolute;
        z-index: 1;
        top: 100%;
        left: 50%;
        margin-left: -60px;
      }

      /* Tooltip text */
      .tooltip .tooltiptext_aboveR {
        visibility: hidden;
        width: 150px;
        background-color: yellow;
        color: #0006ff;
        font-weight: bold;
        text-align: center;
        padding: 5px 0;
        border-radius: 6px;
       
        position: absolute;
        z-index: 1;
        bottom: 100%;
        left: 50%;
        margin-left: -20px;
      }

      .tooltip:hover .tooltiptext_below { visibility: visible; }
      .tooltip:hover .tooltiptext_onit { visibility: visible; }
      .tooltip:hover .tooltiptext_above { visibility: visible; }
      .tooltip:hover .tooltiptext_aboveR { visibility: visible; }
    </style>

    <TABLE><TR><TD><IMG SRC="/images/Vigrid.png" height=124 width=200></TD>
    <TD ALIGN=CENTER VALIGN=MIDDLE>
    <div class="tooltip">
    
    <?php

      $vigrid_type=VIGRIDconfig("VIGRID_TYPE");
      // Standalone server
      if ($vigrid_type==1)
      {
        $desc="Standalone server";
        print("<IMG SRC=\"/images/vigrid_type1.png\" height=90 width=65>");
      }
      // Standalone server + NAS
      else if ($vigrid_type==2)
      {
        $desc="Standalone server with NAS";
        print("<IMG SRC=\"/images/vigrid_type2.png\" height=90 width=62>");
      }
      // MASTER server (scale/farm) + NAS
      else if ($vigrid_type==3)
      {
        $desc="Vigrid Master server with NAS";
        print("<IMG SRC=\"/images/vigrid_type3.png\" height=90 width=77>");
      }

    ?><span class="tooltiptext_onit"><?php print $desc; ?></span></div></TD>
    <TD><FONT SIZE=+2><FONT COLOR="#f75c05">Vigrid <?php print $header; ?> of host <?php print $hostname; ?></FONT></FONT></TD></TR></TABLE><BR>
    <?php
  }

  // To log to vigrid.log file
  function VIGRIDlogging($text)
  {
    $fd=fopen("/var/log/gns3/vigrid.log","a+");
    if (!$fd) { print("Cant write to vigrid.log file. Make sure it is owned by NGinx user who must be granted to write.\n"); return(-1); }
    $host=gethostname();
    $date=date("M j G:i:s");

    fwrite($fd,"$date $hostname $text\n");
		
		fclose($fd);
    return(0);
  }

  // Get HTML value, cleaned from offending characters
  function HTMLvalue($value)
  {
    // print("ENTER=$value\n");
    
    // First extract real value
    $value=html_entity_decode($value);
    
    // Start sanitization
    $value=strip_tags($value,FILTER_SANITIZE_STRING);
    $value=filter_var($value,FILTER_SANITIZE_STRING);

    $value=preg_replace('/[^[A-Z][a-z][0-9]!#$%&\'*+-=?\^_`{|}~@.\[\]. ]+/','',$value);
    
    // print("EXIT =$value\n\n");
    return($value);
  }

  function websockify_getdata()
	{
    $websockify=array();
    
    $vigrid_websockify_options=VIGRIDconfig("VIGRID_WEBSOCKIFY_OPTIONS");

    if ($vigrid_websockify_options!="")
    { $pattern="/\/usr\/bin\/websockify -D $vigrid_websockify_options --web=\/home\/gns3\/vigrid\/www\/no(vnc|telnet)\/ [0-9]* ([0-9]{1,3}\.){3}([0-9]{1,3}):[0-9]*/"; }
    else
    { $pattern="/\/usr\/bin\/websockify -D --web=\/home\/gns3\/vigrid\/www\/no(vnc|telnet)\/ [0-9]* ([0-9]{1,3}\.){3}([0-9]{1,3}):[0-9]*/"; }
			
    $fd=popen("/bin/ps ax","r");
		while (!feof($fd))
		{
			$line=fgets($fd,4096);
			if (preg_match($pattern,$line)) { array_push($websockify,$line); }
    }
		pclose($fd);
    
    return($websockify);
  }
	
  function websockify_check($console_host,$console_port)
	{
		if (($console_host==0) || ($console_port==0))
		{ return (-1); }
  
    $vigrid_websockify_options=VIGRIDconfig("VIGRID_WEBSOCKIFY_OPTIONS");

    if ($vigrid_websockify_options!="")
    {
      $pattern_vnc="/\/usr\/bin\/websockify -D $vigrid_websockify_options --web=\/home\/gns3\/vigrid\/www\/novnc\/ [0-9]* ([0-9]{1,3}\.){3}([0-9]{1,3}):[0-9]*/";
      $pattern_telnet="/\/usr\/bin\/websockify -D $vigrid_websockify_options --web=\/home\/gns3\/vigrid\/www\/notelnet\/ [0-9]* ([0-9]{1,3}\.){3}([0-9]{1,3}):[0-9]*/";
    }
    else
    {
      $pattern_vnc="/\/usr\/bin\/websockify -D --web=\/home\/gns3\/vigrid\/www\/novnc\/ [0-9]* ([0-9]{1,3}\.){3}([0-9]{1,3}):[0-9]*/";
      $pattern_telnet="/\/usr\/bin\/websockify -D --web=\/home\/gns3\/vigrid\/www\/notelnet\/ [0-9]* ([0-9]{1,3}\.){3}([0-9]{1,3}):[0-9]*/";
    }
  
    $websockify=websockify_getdata();
    for ($i=0;$i<sizeof($websockify);$i++)
    {
      // VIGRIDlogging($websockify[$i]);      
      
			if (preg_match($pattern_vnc,$websockify[$i]))
			{
				$t=preg_split("/ /",$websockify[$i]);
				// returns http console port
				if (preg_match("/$console_host:$console_port/",$t[(count($t)-1)]))
				{ return($t[(count($t)-2)]); }
			}
			else if (preg_match($pattern_telnet,$websockify[$i]))
			{
				$t=preg_split("/ /",$websockify[$i]);
				// returns http console port
				if (preg_match("/$console_host:$console_port/",$t[(count($t)-1)]))
				{ return($t[(count($t)-2)]); }
			}
		}
	  return(0);
	}
	
  function get_sys_stats($gns_host)
  {
    if ($gns_host=="")
    { $gns_host=$_SERVER['SERVER_ADDR']; }

		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_URL, "https://$gns_host/vigrid-api/load");

    // Get Vigrid credentials, first got will be fine
    $vigrid_creds=file("/home/gns3/etc/vigrid-passwd");
    $vigrid_creds=preg_replace("/#.*$/","",$vigrid_creds);
    $vigrid_user=trim(preg_replace("/{[a-zA-Z0-9-]+}/","",$vigrid_creds[0]));
    curl_setopt($ch, CURLOPT_USERPWD, $vigrid_user);
    
    curl_setopt($ch, CURLOPT_POSTFIELDS,"{ }");

    if (($vigrid_type>=3) && ($vigrid_type<=5)) { $dirs="$vigrid_storage_root/GNS3/GNS3farm/GNS3,$vigrid_storage_root/NFS"; }

    // curl_setopt($ch, CURLOPT_POSTFIELDS,"{ \"dir\":\"$dirs\" }");
    $data=curl_exec($ch);
		$stats_gns=json_decode($data,true);
		curl_close($ch);
    
    return($stats_gns);
  }

  function get_nas_stats($nas_host)
  {
    // Get Vigrid type for remote directories
    $vigrid_type=VIGRIDconfig("VIGRID_TYPE");
    $hostname=gethostname();
    
    // Not a NAS type, take data locally
    if ($vigrid_type==1) { return(null); }

    // Sanity check
    $vigrid_nas_server=VIGRIDconfig("VIGRID_NAS_SERVER");
    $f=preg_split("/[\s ]+/",$vigrid_nas_server);
    $bad=1;
    for ($i=0;$i<sizeof($f);$i++)
    {
      $g=explode(":",$f[$i]);
      if (($nas_host=="$g[0]") || ($nas_host=="$g[1]")) { $bad=0; }
    }
    if ($bad==1) { return (null); }
    
    $vigrid_storage_root=VIGRIDconfig("VIGRID_STORAGE_ROOT");
    
    $dirs="";
    if ($vigrid_type==1) { $dirs="$vigrid_storage_root/home/gns3/GNS3"; }
    if ($vigrid_type==2) { $dirs="$vigrid_storage_root/NFS/$hostname/GNS3"; }
    if (($vigrid_type>=3) && ($vigrid_type<=5)) { $dirs="$vigrid_storage_root/GNS3/GNS3farm/GNS3,$vigrid_storage_root/NFS"; }

		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_URL, "https://$nas_host/vigrid-nas-api/nas-load");
    curl_setopt($ch, CURLOPT_POSTFIELDS,"{ \"dir\":\"$dirs\" }");
    $data=curl_exec($ch);
		$stats_nas=json_decode($data,true);
		curl_close($ch);
    
    return($stats_nas);   
  }  

	// get DHCP leases : WARNING, totally dependant of DHCP server + implementation.
	// Probably much cleaner way to get active DHCP leases...
	function get_dhcp_leases()
	{
		$dhcp_leases=array();

    $dhcp_server=VIGRIDconfig("VIGRID_DHCP_SERVER");
    $f=explode(":",$dhcp_server);
    $dhcp_server=$f[1]; // IP is better than hostname :-)
    if ($dhcp_server!="") { $dhcp_flag="-H $dhcp_server"; }
    
		// /home/gns3/bin/dhcp-list-leases script will provide infos, that is a DHCPACK message in time_t order
		$fd=popen("sudo -u gns3 /home/gns3/vigrid/bin/dhcp-list-leases $dhcp_flag","r");
		while (!feof($fd))
		{
			$line=fgets($fd,4096);
			if (preg_match("/dhcpd.*DHCPACK/",$line))
			{
				$dhcp_record=preg_split("/\s+/",$line);
				$dhcp_mac=$dhcp_record[9];
				$dhcp_ip=$dhcp_record[7];
				// print("M=".$dhcp_mac.", IP=".$dhcp_ip."\n");
				// Since last replace previous, array will contain unique last IP/MAC pair
				$dhcp_leases[$dhcp_mac]=$dhcp_ip;
			}
		}
		pclose($fd);

		return($dhcp_leases);
	}
	
	function rollback_snapshot($gns_host,$project_uuid,$node_uuid,$snapshot_id)
	{
		if (($gns_host=="") || ($project_uuid=="") || ($node_uuid=="") || ($snapshot_id==""))
		{ return array(0,""); }

    $vigrid_storage_mode=VIGRIDconfig("VIGRID_STORAGE_MODE");

		$fd=popen("/home/gns3/vigrid/bin/project".$vigrid_storage_mode."snapshot -c -a rollback -h $gns_host -p $project_uuid -n $node_uuid -s $snapshot_id","r");
		while (!feof($fd))
		{
			$line=fgets($fd,4096);
			$line=trim($line);
			if (preg_match("/1=OK;2=OK/",$line)) { pclose($fd); return array(1,$line); }
			else if (preg_match("/BAD/",$line))  { pclose($fd); return array(0,$line); }
		}
		// normally last always OK or BAD so useless
		pclose($fd);
		return array(0,"");
	}
	
	function get_snapshots($project_uuid,$node_uuid)
	{
		$snapshots=array();
    
    $vigrid_storage_mode=VIGRIDconfig("VIGRID_STORAGE_MODE");

		if ($node_uuid!="")
		{ $command="sudo /home/gns3/vigrid/bin/project".$vigrid_storage_mode."snapshot -a list -p $project_uuid -n $node_uuid"; }
    else
		{ $command="sudo /home/gns3/vigrid/bin/project".$vigrid_storage_mode."snapshot -a list -p $project_uuid"; }
  
    // print("COMMAND=$command<BR>");
    // script can return:
    // S=snapshot
    // BAD=Project is not a XXX volume
    // No snapshot detected.
    $fd=popen($command,"r");
		while (!feof($fd))
		{
			$line=fgets($fd,4096);
			if (preg_match("/^S=/",$line))
      {
        $line=preg_replace("/^S=/","",$line);
        trim($line);
        array_push($snapshots,$line);
      }
      else if (preg_match("/not a $vigrid_storage_mode volume/i",$line))
      {
        // $rc=pclose($fd);
        // return array(-1,"");
        break;
      }
		}
		$rc=pclose($fd);
		return array($rc,$snapshots);
	}

	function compare_name($a, $b)
  { return strnatcmp($a['name'], $b['name']); }
	
  function gns_getservers_by_projectname($gns_controller,$data_vigrid,$project_name)
  {
    $list=array();
	
    for ($i=0;$i<sizeof($gns_controller['computes']);$i++)
    {
      for ($j=0;$j<sizeof($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS']);$j++)
      {
        if ($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_name']==$project_name)
        { array_push($list,$gns_controller['computes'][$i]['name']);}
      }
    }

    usort($list, 'compare_name');
    return($list);
  }

  function gns_getservers_by_projectuuid($gns_controller,$data_vigrid,$project_uuid)
  {
    $list=array();
	
    for ($i=0;$i<sizeof($gns_controller['computes']);$i++)
    {
      for ($j=0;$j<sizeof($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS']);$j++)
      {
        if ($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_id']==$project_uuid)
        { array_push($list,$gns_controller['computes'][$i]['name']);}
      }
    }

    usort($list, 'compare_name');
    return($list);
  }

  function gns_getprojectname_by_macaddr($gns_controller,$data_vigrid,$macaddr)
  {
    for ($i=0;$i<sizeof($gns_controller['computes']);$i++)
    {
      for ($j=0;$j<sizeof($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS']);$j++)
      {
        for ($k=0;$k<sizeof($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECT_NODES'][$data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_id']]['NODES']);$k++)
        {
          for ($p=0;$p<sizeof($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECT_NODES'][$data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_id']]['NODES'][$k]['ports']);$p++)
          {
            if ($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECT_NODES'][$data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_id']]['NODES'][$k]['ports'][$p]['mac_address']!="")
            {
              if (strcasecmp($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECT_NODES'][$data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_id']]['NODES'][$k]['ports'][$p]['mac_address'],$macaddr)==0)
              { return($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['name']); }
            }
          }
        }
      }
    }
    return("UNKNOWN");
  }
  
  function gns_getprojectname_by_projectuuid($gns_controller,$data_vigrid,$project_uuid)
  {
    for ($i=0;$i<sizeof($gns_controller['computes']);$i++)
    {
      if (isset($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS']))
      {
        for ($j=0;$j<sizeof($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS']);$j++)
        {
          if ($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_id']==$project_uuid)
          { return($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['name']); }
        }
      }
    }
  }
	
  function gns_gethost_by_projectuuid($gns_controller,$data_vigrid,$project_uuid)
  {
    for ($i=0;$i<sizeof($gns_controller['computes']);$i++)
    {
      for ($j=0;$j<sizeof($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS']);$j++)
      {
        if ($data_vigrid['GNS3'][$gns_controller['computes'][$i]['host']]['PROJECTS'][$j]['project_id']==$project_uuid)
        { return($gns_controller['computes'][$i]['name']); }
      }
    }
  }
  
	function gns_getserver_config()
	{
    $vigrid_storage_root=VIGRIDconfig("VIGRID_STORAGE_ROOT");
		$config_file="$vigrid_storage_root/home/gns3/.config/GNS3/gns3_server.conf";

    $gns_server_conf=array();

    $fd=fopen($config_file,"r");
    if (!$fd) { print("Cant open $config_file !!, stopping\n"); exit; }
    while (($line = fgets($fd, 4096)) !== false)
    {
			if (preg_match("/=/",$line))
      {
        // Lines are shell variables (var=value, var="value", var='value')
        $line=trim($line);
        
        $f=explode("=",$line);

        $var_name=trim($f[0]);
        $var_name=preg_replace("/[\s ]*/","",$var_name);
        $var_name=preg_replace("/[#;].*$/","",$var_name);

        array_shift($f);
        $var_value=implode("=",$f);
        $var_value=preg_replace("/^[\"']/","",$var_value);
        $var_value=preg_replace("/[\"']$/","",$var_value);
        $gns_server_conf[$var_name]=trim($var_value);
      }
    }
		
		fclose($fd);
    
		return($gns_server_conf);
	}
	
	function gns_getcontrollers()
	{
		// Opening GNS3 controller config file to get GNS3 servers list & details from JSON data
    $vigrid_storage_root=VIGRIDconfig("VIGRID_STORAGE_ROOT");
		$config_file="$vigrid_storage_root/home/gns3/.config/GNS3/gns3_controller.conf";

		$gns_controller_json="";
	
		$fd=fopen($config_file,"r");
		if (!$fd) { print("Cant open $config_file !!, stopping\n"); exit; }
		while (($line = fgets($fd, 4096)) !== false)
		{ $gns_controller_json="$gns_controller_json $line"; }
		fclose($fd);

		// computes already present ?
		$computes=1;
		if (preg_match("/\"computes\": \[\]/",$gns_controller_json)) { $computes=0; }

		// insert localserver as compute|0]
		$_tmp_gns_server=gns_getserver_config();
		
    $_tmp_localserver='"computes": [
         {
            "host": "'.$_tmp_gns_server['host'].'",
            "name": "'.gethostname().'",
            "port": '.$_tmp_gns_server['port'].',
            "protocol": "http",
            "user": "'.$_tmp_gns_server['user'].'",
            "password": "'.$_tmp_gns_server['password'].'"
         }';

		if ($computes==1)
		{ $_tmp_localserver=$_tmp_localserver.","; }

	  $_tmp_localserver=$_tmp_localserver."
		";
		$gns_controller_json=preg_replace("/\"computes\": \[/",$_tmp_localserver,$gns_controller_json);
		
		// print("JSON=".$gns_controller_json);

		$gns_controller=json_decode($gns_controller_json,true);

		return($gns_controller);
	}
	
	function gns_gethostnumbyname($gns_controller,$hostname)
	{
		for ($h=0;$h<sizeof($gns_controller['computes']);$h++)
		{
			if ((strcasecmp($gns_controller['computes'][$h]['name'],$hostname)==0)
       || (strcasecmp($gns_controller['computes'][$h]['host'],$hostname)==0))
			{ return ($h); }
		}
		return (-1);
	}
	
	function gns_gethostnumbyip($gns_controller,$hostip)
	{
		return(gns_gethostnumbyname($gns_controller,$hostip));
	}

  function gns_getcomputes($gns_controller,$hostname)
  {
    
    if (VIGRIDconfig("VIGRID_GNS_VERSION")=="")
    { VIGRIDlogging("Cant find VIGRID_GNS_VERSION into vigrid configuration file"); return(null); }
  
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/computes");

    // print("Connecting to url: $url\n<BR>");
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
    curl_setopt($ch, CURLOPT_URL, $url);
    $computes_json=curl_exec($ch);
    curl_close($ch);

    $computes=json_decode($computes_json,true);
    return($computes);
  }

	function gns_getcomputesASYNC($gns_controller,$hostname)
	{
    $computes=array();
    $url=array();
    
    // If there are GNS slaves into Vigrid.conf AND that is a SLAVE (not scalable) MASTER server, use them instead
    $vigrid_type=VIGRIDconfig("VIGRID_TYPE");
    $vigrid_slaves=VIGRIDconfig("VIGRID_GNS_SLAVE_HOSTS");
    
    if (($vigrid_type==3) && ($vigrid_slaves!="")) // Farm master
    {
      // Format: hostname:IP:port
      $vigrid_slave_hosts=preg_split("/[\s ]+/",$vigrid_slaves);
    }
    else
    {
      $hostnum=gns_gethostnumbyname($gns_controller,$hostname);
      if ($hostnum==-1)
      {
        // Maybe host IP was given instead of name, try another way
        $hostnum=gns_gethostnumbyip($gns_controller,$hostname);
        if ($hostnum==-1) { return(null); }
      }

      // Format: hostname:IP:port
      $vigrid_slave_hosts=array($gns_controller['computes'][$hostnum]['host'].":".$gns_controller['computes'][$hostnum]['host'].":".$gns_controller['computes'][$hostnum]['port']);
    }
    
    // Sort hosts
    natcasesort($vigrid_slave_hosts);
    $vigrid_slave_hosts=array_values($vigrid_slave_hosts);

    // Now run in parallel: get computes, then get projects, finally getnodes
    $mh = curl_multi_init();

    for ($s=0;$s<sizeof($vigrid_slave_hosts);$s++)
    {
      $f=explode(":",$vigrid_slave_hosts[$s]);
      $url[$s]="http://".$f[1].":".$f[2]."/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/computes";
      
      $ch[$s] = curl_init();
      curl_setopt($ch[$s], CURLOPT_SSL_VERIFYPEER, false);
      curl_setopt($ch[$s], CURLOPT_RETURNTRANSFER, true);
      curl_setopt($ch[$s], CURLOPT_CONNECTTIMEOUT, 3);
      curl_setopt($ch[$s], CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
      curl_setopt($ch[$s], CURLOPT_URL, $url[$s]);
      
      curl_multi_add_handle($mh,$ch[$s]);
    }

    do
    {
      $status = curl_multi_exec($mh, $active);
      
      if ($active) { curl_multi_select($mh); }
          
      // echo "Waiting (A=$active,S=$status)\n";
    } while ($active && $status == CURLM_OK);

    for ($s=0;$s<sizeof($vigrid_slave_hosts);$s++)
    {
      $data_json=json_decode(curl_multi_getcontent($ch[$s]),true);
      
      if (!is_null($data_json))
      {
        $computes[$s]=$data_json;
        // alpha sort nodes...
      }
      
      curl_multi_remove_handle($mh,$ch[$s]);
    }

    curl_multi_close($mh);

    // usort($computes,'compare_name');
    
    return($computes);
	}

  function VIGRIDgetgnshosts($gns_controller)
  {
    $vigrid_hosts=array();

    $vigrid_type=VIGRIDconfig("VIGRID_TYPE");   
    $vigrid_slaves=VIGRIDconfig("VIGRID_GNS_SLAVE_HOSTS");
    if (($vigrid_type==3) && ($vigrid_slaves!="")) // Farm master
    {
      // Format: hostname:IP:port
      $gns_list=preg_split("/[\s ]+/",$vigrid_slaves);
      for ($c=0;$c<sizeof($gns_list);$c++)
      {
        $f=explode(":",$gns_list[$c]);
        if (!in_array("$f[0]:$f[1]:$f[2]:",$vigrid_hosts))
        { array_push($vigrid_hosts,"$f[0]:$f[1]:$f[2]:local"); }
      }
    }
		// Format: hostname:IP:port
		for ($c=0;$c<sizeof($gns_controller['computes']);$c++)
		{
      $str=$gns_controller['computes'][$c]['name'].":".$gns_controller['computes'][$c]['host'].":".$gns_controller['computes'][$c]['port'];
      if ((!in_array("$str:",$vigrid_hosts)) && (!in_array("$str:local",$vigrid_hosts)))
      { array_push($vigrid_hosts,$gns_controller['computes'][$c]['name'].":".$gns_controller['computes'][$c]['host'].":".$gns_controller['computes'][$c]['port'].":".$gns_controller['computes'][$c]['compute_id']); }
    }
    
    // Clean possible mistakes
    $vigrid_hosts=preg_grep('/::/',$vigrid_hosts,PREG_GREP_INVERT);

    // Sort hosts
    natcasesort($vigrid_hosts);
    $vigrid_hosts=array_values($vigrid_hosts);
    
    // Move Master to top of list
    for ($i=0;$i<sizeof($vigrid_hosts);$i++)
    {
      $f=explode(":",$vigrid_hosts[$i]);
      if (!strcasecmp($f[0],gethostname()))
      {
        $t=$vigrid_hosts[$i];
        unset($vigrid_hosts[$i]);
        array_unshift($vigrid_hosts,$t);
        break;
      }
    }
    $vigrid_hosts=array_unique($vigrid_hosts);
    $vigrid_hosts=array_values($vigrid_hosts);
    
    return($vigrid_hosts);
  }

	function gns_project_command($gns_controller,$hostname,$project_id,$order,$order_data=null)
	{

    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/".$order);
    if ($url=="") { return(null); }

		// print("URL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
		curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
    
    if ($order_data)
    {
      $data_json = json_encode($order_data);
      // print("SENDING "); print_r($data_json); print("<BR><BR>");
      curl_setopt($ch, CURLOPT_POSTFIELDS,$data_json);
    }
    else { curl_setopt($ch, CURLOPT_POSTFIELDS, "{}"); }
		$json=curl_exec($ch);
		curl_close($ch);

    if ($json=="") return(null);
    
		return ($json);
	}

	function gns_project_delete($gns_controller,$hostname,$project_id)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/".$order);
    if ($url=="") { return(null); }

		// print("URL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
		// curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "DELETE");
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_POSTFIELDS, "{}");
		$json=curl_exec($ch);
		curl_close($ch);

		return ($json);
	}
	
	function gns_getprojects($gns_controller,$hostname)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects");
    if ($url=="") { return(null); }

		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		$projects_json=curl_exec($ch);
		curl_close($ch);
	
		$projects=json_decode($projects_json,true);
		
		return($projects);
	}

	function gns_getprojectsASYNC($gns_controller,$hostname)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects");
    if ($url=="") { return(null); }

		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		$projects_json=curl_exec($ch);
		curl_close($ch);
	
		$projects=json_decode($projects_json,true);
		
		return($projects);
	}
	
	function gns_getnodes($gns_controller,$hostname,$project_id)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/nodes");
    if ($url=="") { return(null); }

		// print("getnodesURL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		$nodes_json=curl_exec($ch);
		curl_close($ch);

		// print("<tt>getnodesJSON=$nodes_json</tt>");
		$nodes=json_decode($nodes_json,true);
		
		return($nodes);
	}

	function gns_getlinks($gns_controller,$hostname,$project_id)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/links");
    if ($url=="") { return(null); }

		// print("getlinksURL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		$links_json=curl_exec($ch);
		curl_close($ch);

		// print("<tt>getlinksJSON=$links_json</tt>");
		$links=json_decode($links_json,true);
    
		return($links);
	}

	function gns_link_command($gns_controller,$hostname,$project_id,$link_id,$filter_array)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/links/".$link_id);
    if ($url=="") { return(null); }

		// print("gns_link_commandURL=$url<BR>\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
		curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "PUT");
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);

    $data_json = json_encode($filter_array);
    // print("SENDING "); print_r($data_json); print("<BR><BR>");
    curl_setopt($ch, CURLOPT_POSTFIELDS,$data_json);

		$json=curl_exec($ch);
		curl_close($ch);

    // print("<BR>RETURNED "); print_r($json);
		return($json);
	}

	function gns_getprojectnamebyuuid($gns_host,$project_uuid)
	{
		$gns_controller=gns_getcontrollers();
		$gns_projects=gns_getprojects($gns_controller,$gns_host);
		for ($i=0;$i<sizeof($gns_projects);$i++)
		{
			if ($gns_projects[$i]['project_id'] == $project_uuid)
			{ return ($gns_projects[$i]['name']); }
		}
		return("");
	}
	
	function gns_getnodenamebyuuid($gns_host,$project_uuid,$node_uuid)
	{
		$gns_controller=gns_getcontrollers();
		$gns_nodes=gns_getnodes($gns_controller,$gns_host,$project_uuid);
		for ($i=0;$i<sizeof($gns_nodes);$i++)
		{
			if ($gns_nodes[$i]['node_id'] == $node_uuid)
			{ return ($gns_nodes[$i]['name']); }
		}
		return("");
	}

	function gns_getnode_info($gns_controller,$hostname,$project_id,$node_id)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/nodes/".$node_id);
    if ($url=="") { return(null); }

		// print("getnodesURL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		$node_json=curl_exec($ch);
		curl_close($ch);

		// print("<tt>getnodesJSON=$nodes_json</tt>");
		$node=json_decode($node_json,true);
		
		return($node);
	}

	function gns_getlinkstatus($gns_controller,$hostname,$project_id,$node_id,$port_number)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/links");
    if ($url=="") { return(null); }

		// print("getlinksURL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		$links_json=curl_exec($ch);
		curl_close($ch);
		
		$node_info=gns_getnode_info($gns_controller,$hostname,$project_id,$node_id);

		// print("<tt>getnodesJSON=$links_json</tt>");
		$links=json_decode($links_json,true);
		// print_r($links);
    if (isset($links))
    {
      for ($i=0;$i<sizeof($links);$i++)
      {
        if (isset($links[$i]['nodes']))
        {
          for ($j=0;$j<sizeof($links[$i]['nodes']);$j++)
          {
            if ($links[$i]['nodes'][$j]['node_id'] == $node_id) // nodes must match
            {
              // print("P=".$project_id.", N=".$node_id.", Port=".$port_number.", Link=".$links[$i]['nodes'][$j]['port_number']."\n");
              // if ($links[$i]['nodes'][$j]['label']['text'] == $port_number)
              if (($links[$i]['nodes'][$j]['port_number'] == $port_number) && ($node_info['status']=='started'))
              { return (1); }
            }
          }
        }
      }
    }
		return(0); // unplugged or off
	}

	function gns_node_command($gns_controller,$hostname,$project_id,$node_id,$order)
	{
    $url=VIGRIDgetgnshosturl($gns_controller,$hostname,"/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$project_id."/nodes/".$node_id."/".$order);
    if ($url=="") { return(null); }
        
		// print("gns_node_commandURL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
		curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_POSTFIELDS, "{}");
		$json=curl_exec($ch);
		curl_close($ch);
		
		return($json);
	}
	
	function gns_node_on_host($gns_controller_host,$node)
	{
		// print("/ ".$gns_controller_host['host'].":/ vs \"".$node['command_line']."\"<BR>");
		if (preg_match("/ ".$gns_controller_host['host'].":/",$node['command_line'])) { return(1); } // works only with VNC

		if (($node['console_host']!="") && ($node['console']!=""))
		// another method : telnet to node console port that should work if running
		{		
			$fp = fsockopen($node['console_host'], $node['console'], $errno, $errstr, 1);
			if (!$fp) { return(0); } else { fclose($fp); return(1); }
		}

		return(0);
	}

	function msConnectSocket($remote, $port, $timeout = 1)
	{
		# this works whether $remote is a hostname or IP
		$ip = "";
		if( !preg_match('/^\d+\.\d+\.\d+\.\d+$/', $remote) ) {
				$ip = gethostbyname($remote);
				if ($ip == $remote) {
						$this->errstr = "Error Connecting Socket: Unknown host";
						return NULL;
				}
		} else $ip = $remote;

		if (!($this->_SOCK = @socket_create(AF_INET, SOCK_STREAM, SOL_TCP))) {
				$this->errstr = "Error Creating Socket: ".socket_strerror(socket_last_error());
				return NULL;
		}

		socket_set_nonblock($this->_SOCK);

		$error = NULL;
		$attempts = 0;
		$timeout *= 1000;  // adjust because we sleeping in 1 millisecond increments
		$connected;
		while (!($connected = @socket_connect($this->_SOCK, $remote, $port+0)) && $attempts++ < $timeout) {
				$error = socket_last_error();
				if ($error != SOCKET_EINPROGRESS && $error != SOCKET_EALREADY) {
						$this->errstr = "Error Connecting Socket: ".socket_strerror($error);
						socket_close($this->_SOCK);
						return NULL;
				}
				usleep(1000);
		}

		if (!$connected) {
				$this->errstr = "Error Connecting Socket: Connect Timed Out After $timeout seconds. ".socket_strerror(socket_last_error());
				socket_close($this->_SOCK);
				return NULL;
		}

		socket_close($this->_SOCK);
		return 1;     
	 
		socket_set_block($this->_SOCK);

		return 1;     
  }

  function VIGRIDgetstatsdata($gns_controller)
  {
    global $verbose;
    
    $data_vigrid_stats=array();
    
    $ping=array();
    $socket=array();
    $error=array();
    $done=array();

    // sort alpha computes...
    // Move myself (master) at top of list
    usort($gns_controller['computes'], 'compare_name');

    // Change reporting to remove socket warnings...
    $current_error=error_reporting();
    error_reporting(E_ALL ^ E_NOTICE ^ E_WARNING);

    for ($i=0;$i<sizeof($gns_controller['computes']);$i++)
    {
      $ping[$i]=0;
      $done[$i]=0;

      $socket[$i]=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
      socket_set_nonblock($socket[$i]);
    }

    // What is current time in microseconds ?
    $micro_time_start=microtime(true);
    
    $attempts=0;
    while (1)
    {
      $done_all=1;
      
      for ($i=0;$i<sizeof($gns_controller['computes']);$i++)
      {
        if ($done[$i]==0) { $done_all=0; }
        
        if ($done[$i]==0)
        {
          $cnx[$i]=socket_connect($socket[$i],$gns_controller['computes'][$i]['name'],$gns_controller['computes'][$i]['port']);
          $error[$i]=socket_last_error();

          if ($error[$i]==SOCKET_EISCONN) // Socket is connected
          {
            socket_close($socket[$i]);

            // Server is up, getting data

            // NAS ?
            $vigrid_type=VIGRIDconfig("VIGRID_TYPE");

            if ($vigrid_type!=1) // Design with NAS
            {
              $vigrid_nas=VIGRIDconfig("VIGRID_NAS_SERVER");
              $nas_list=preg_split("/[\s ]+/",$vigrid_nas);
              for ($n=0;$n<sizeof($nas_list);$n++)
              {
                $nas=explode(":",$nas_list[$n]);
                $nas_host=$nas[0];
                $nas_ip=$nas[1];

                $data_vigrid_stats['STATS'][$nas_host]=get_nas_stats($nas_ip);
              }
            }
            
            // Host monitoring stats
            if (gethostname()==$gns_controller['computes'][$i]['name'])
            { $data_vigrid_stats['STATS'][$gns_controller['computes'][$i]['host']]=get_sys_stats(""); }
            else
            { $data_vigrid_stats['STATS'][$gns_controller['computes'][$i]['host']]=get_sys_stats($gns_controller['computes'][$i]['host']); }
          
            $done[$i]=1;
          }
        }
      }

      // Delay management
      // 50ms wait, max 8 times (400ms total) + delay to get the info.
      // Since getting the info takes time we should not loose again, after 500ms passed, a last turn to finish

      $micro_time_current=microtime(true);
          
      if (($attempts++>15) || ($done_all==1)) { break; } // 3000ms max delay are enough, or job done
      else if ($micro_time_current-$micro_time_start>3) { $attempts=20; } // 2500ms already passed, enough ! a last turn
      else { usleep(200000); }
    }

    error_reporting($current_error);          
    
    return($data_vigrid_stats);
  }

  function VIGRIDgetstatsdataASYNC($gns_controller)
  {
    global $verbose;
    
    $data_vigrid_stats=array();
    $vigrid_hosts=array();
    
    $ping=array();
    $socket=array();
    $error=array();
    $done=array();

    // NAS ?
    $vigrid_type=VIGRIDconfig("VIGRID_TYPE");

    if ($vigrid_type==1) // Standalone -> local storage
    {
      include "/home/gns3/vigrid/www/site/manager/vigrid-host-api_functions.php";
      $data_vigrid_stats['STATS'][$gns_controller['computes'][0]['host']]=get_sys_stats("");
      
      // Extract dir sizes directly
      if (file_exists(VIGRIDconfig("VIGRID_STORAGE_ROOT")) && is_dir(VIGRIDconfig("VIGRID_STORAGE_ROOT")))
      {
        $disk_free =HumanSize(disk_free_space(VIGRIDconfig("VIGRID_STORAGE_ROOT")));
        $disk_total=HumanSize(disk_total_space(VIGRIDconfig("VIGRID_STORAGE_ROOT")));
        
        $data_vigrid_stats['STATS'][$gns_controller['computes'][0]['host']]['dir'][VIGRIDconfig("VIGRID_STORAGE_ROOT")]['space']="$disk_free/$disk_total";

      }
      return($data_vigrid_stats);
    }
    else if ($vigrid_type!=1) // Design with NAS
    {
      $vigrid_nas=VIGRIDconfig("VIGRID_NAS_SERVER");
      $nas_list=preg_split("/[\s ]+/",$vigrid_nas);
      for ($n=0;$n<sizeof($nas_list);$n++)
      {
        $nas=explode(":",$nas_list[$n]);
        $nas_host=$nas[0];
        $nas_ip=$nas[1];

        array_push($vigrid_hosts,"NAS:".$nas_host.":".$nas_ip);
      }
    }
    
    // If there are GNS slaves into Vigrid.conf AND that is a SLAVE (not scalable) MASTER server, use them instead
    $vigrid_slaves=VIGRIDconfig("VIGRID_GNS_SLAVE_HOSTS");
    
    if (($vigrid_type==3) && ($vigrid_slaves!="")) // Farm master
    {
      // Format: hostname:IP:port
      $gns_list=preg_split("/[\s ]+/",$vigrid_slaves);
      for ($c=0;$c<sizeof($gns_list);$c++)
      {
        $f=explode(":",$gns_list[$c]);
        array_push($vigrid_hosts,"GNS:$f[0]:$f[1]:$f[2]");
      }
    }
    else
    {
      // sort alpha computes...
      // Move myself (master) at top of list
      usort($gns_controller['computes'], 'compare_name');

      // Format: hostname:IP:port
      for ($c=0;$c<sizeof($gns_controller['computes']);$c++)
      { array_push($vigrid_hosts,"GNS:".$gns_controller['computes'][$c]['name'].":".$gns_controller['computes'][$c]['host'].":".$gns_controller['computes'][$c]['port']); }
    }

    // Sort hosts
    $vigrid_hosts=array_unique($vigrid_hosts);
    natcasesort($vigrid_hosts);
    $vigrid_hosts=array_values($vigrid_hosts);

    // Change reporting to remove socket warnings...
    $current_error=error_reporting();
    error_reporting(E_ALL ^ E_NOTICE ^ E_WARNING);

    for ($i=0;$i<sizeof($vigrid_hosts);$i++)
    {
      $ping[$i]=0;
      $done[$i]=0;

      $socket[$i]=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
      socket_set_nonblock($socket[$i]);
    }

    // What is current time in microseconds ?
    $micro_time_start=microtime(true);
    
    $attempts=0;
    while (1)
    {
      $done_all=1;
      
      for ($i=0;$i<sizeof($vigrid_hosts);$i++)
      {
        if ($done[$i]==0) { $done_all=0; }
        
        if ($done[$i]==0)
        {
          $f=explode(":",$vigrid_hosts[$i]);
          $ip_type=$f[0];
          $ip_name=$f[1];
          $ip_address=$f[2];
          
          // host:22
          $cnx[$i]=socket_connect($socket[$i],$ip_address,22); // That is SSH scripts
          $error[$i]=socket_last_error();

          if ($error[$i]==SOCKET_EISCONN) // Socket is connected
          {
            socket_close($socket[$i]);

            // Server is up, getting monitoring stats
            if ($ip_type=="GNS")
            {
              if (gethostname()==$ip_name)
              { $data_vigrid_stats['STATS'][$ip_address]=get_sys_stats(""); }
              else
              { $data_vigrid_stats['STATS'][$ip_address]=get_sys_stats($ip_address); }
            }
            else if ($ip_type=="NAS")
            {
              if (gethostname()==$ip_name)
              { $data_vigrid_stats['STATS'][$ip_address]=get_nas_stats(""); }
              else
              { $data_vigrid_stats['STATS'][$ip_address]=get_nas_stats($ip_address); }
            }
          
            $done[$i]=1;
          }
        }
      }

      // Delay management
      // 50ms wait, max 8 times (400ms total) + delay to get the info.
      // Since getting the info takes time we should not loose again, after 500ms passed, a last turn to finish

      $micro_time_current=microtime(true);
          
      if (($attempts++>15) || ($done_all==1)) { break; } // 3000ms max delay are enough, or job done
      else if ($micro_time_current-$micro_time_start>3) { $attempts=20; } // 2500ms already passed, enough ! a last turn
      else { usleep(200000); }
    }

    return($data_vigrid_stats);
  }
  
  function VIGRIDgetgnsdata($gns_controller)
  {
    global $verbose;
    
    $data_vigrid=array();
    
    $ping=array();
    $socket=array();
    $error=array();
    $done=array();

    $vigrid_hosts=VIGRIDgetgnshosts($gns_controller);

    // Change reporting to remove socket warnings...
    $current_error=error_reporting();
    error_reporting(E_ALL ^ E_NOTICE ^ E_WARNING);

    for ($i=0;$i<sizeof($vigrid_hosts);$i++)
    {
      $ping[$i]=0;
      $done[$i]=0;

      $socket[$i]=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
      socket_set_nonblock($socket[$i]);
    }

    // What is current time in microseconds ?
    $micro_time_start=microtime(true);
    
    $attempts=0;
    while (1)
    {
      $done_all=1;
      
      for ($i=0;$i<sizeof($vigrid_hosts);$i++)
      {
        if ($done[$i]==0) { $done_all=0; }
        
        if ($done[$i]==0)
        {
          $f=explode(":",$vigrid_hosts[$i]);
          $ip_name=$f[0];
          $ip_address=$f[1];
          $ip_port=$f[2];
          $ip_compute=$f[3];

          $cnx[$i]=socket_connect($socket[$i],$ip_address,$ip_port);
          $error[$i]=socket_last_error();

          if ($error[$i]==SOCKET_EISCONN) // Socket is connected
          {
            socket_close($socket[$i]);

            // Server is up, getting data
            // GNS3 data
            $data_vigrid['GNS3'][$ip_address]['COMPUTES']=gns_getcomputes($gns_controller,$ip_address);
            
            $data_vigrid['GNS3'][$ip_address]['PROJECTS']=gns_getprojects($gns_controller,$ip_address);
            if (isset($data_vigrid['GNS3'][$ip_address]['PROJECTS']))
            {
              usort($data_vigrid['GNS3'][$ip_address]['PROJECTS'], 'compare_name');

              for ($j=0;$j<sizeof($data_vigrid['GNS3'][$ip_address]['PROJECTS']);$j++)
              {
                // gns_project_command($gns_controller,$ip_address,$data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['project_id'],"open");

                // Get nodes only if project is opened
                if ((isset($data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['status']))
                 && ($data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['status']=="opened"))
                {
                  $data_vigrid['GNS3'][$ip_address]['PROJECT_NODES'][$data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['project_id']]['NODES']
                    =gns_getnodes($gns_controller,$ip_address,$data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['project_id']);
               
                  // alpha sort nodes...
                  usort($data_vigrid['GNS3'][$ip_address]['PROJECT_NODES'][$data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['project_id']]['NODES'], 'compare_name');
                }
              }
            }

            $done[$i]=1;
          }
        }
      }

      // Delay management
      // 50ms wait, max 8 times (400ms total) + delay to get the info.
      // Since getting the info takes time we should not loose again, after 500ms passed, a last turn to finish

      $micro_time_current=microtime(true);
          
      if (($attempts++>15) || ($done_all==1)) { break; } // 3000ms max delay are enough, or job done
      else if ($micro_time_current-$micro_time_start>3000000) { $attempts=14; } // 3000ms already passed, enough ! a last turn
      else { usleep(200000); }
    }

    error_reporting($current_error);
    
    return($data_vigrid);
  }

  function VIGRIDgetgnsdataASYNC($gns_controller)
  {
    global $verbose;
    
    $data_vigrid=array();
    
    $ping=array();
    $socket=array();
    $error=array();
    $done=array();

    $vigrid_hosts=VIGRIDgetgnshosts($gns_controller);

    // Change reporting to remove socket warnings...
    $current_error=error_reporting();
    error_reporting(E_ALL ^ E_NOTICE ^ E_WARNING);

    for ($i=0;$i<sizeof($vigrid_hosts);$i++)
    {
      $ping[$i]=0;
      $done[$i]=0;

      $socket[$i]=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
      socket_set_nonblock($socket[$i]);
    }

    // What is current time in microseconds ?
    $micro_time_start=microtime(true);
    
    $attempts=0;
    while (1)
    {
      $done_all=1;
      
      for ($i=0;$i<sizeof($vigrid_hosts);$i++)
      {
        if ($done[$i]==0) { $done_all=0; }
        
        if ($done[$i]==0)
        {
          $f=explode(":",$vigrid_hosts[$i]);
          $ip_name=$f[0];
          $ip_address=$f[1];
          $ip_port=$f[2];
          $ip_compute=$f[3];

          $cnx[$i]=socket_connect($socket[$i],$ip_address,$ip_port);
          $error[$i]=socket_last_error();

          if ($error[$i]==SOCKET_EISCONN) // Socket is connected
          {
            socket_close($socket[$i]);

            // Server is up, getting data

            // GNS3 data
            // When not a FARM SLAVE MASTER SERVER, return start of json data for specific host
            // $data_vigrid['GNS3'][$ip_address]['COMPUTES']=gns_getcomputes($gns_controller,$ip_address);

            // ELSE, return the full computes array per host, must be converted to Vigrid format
            // $computes=gns_getcomputesASYNC($gns_controller,"");
           
            // for ($c=0;$c<sizeof($computes);$c++)
            // { $data_vigrid['GNS3'][$computes[$c][0]['host']['COMPUTES']]=$computes[$c][0]; }

            $data_vigrid['GNS3'][$ip_address]['COMPUTES']=gns_getcomputesASYNC($gns_controller,$ip_address);
            
            $data_vigrid['GNS3'][$ip_address]['PROJECTS']=gns_getprojectsASYNC($gns_controller,$ip_address);
            usort($data_vigrid['GNS3'][$ip_address]['PROJECTS'], 'compare_name');

            // Now run in parallel: get computes, then get projects, finally getnodes
            $mh = curl_multi_init();
            
            for ($j=0;$j<sizeof($data_vigrid['GNS3'][$ip_address]['PROJECTS']);$j++)
            {
              // Get nodes only if project is opened
              if ($data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['status']=="opened")
              {
                $url="http://".$ip_address.":".$ip_port;
                $url.="/v".VIGRIDconfig("VIGRID_GNS_VERSION")."/projects/".$data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['project_id']."/nodes";

                $ch[$j] = curl_init();
                curl_setopt($ch[$j], CURLOPT_SSL_VERIFYPEER, false);
                curl_setopt($ch[$j], CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch[$j], CURLOPT_CONNECTTIMEOUT, 3);
                curl_setopt($ch[$j], CURLOPT_USERPWD, VIGRIDconfig("VIGRID_GNS_USER").":".VIGRIDconfig("VIGRID_GNS_PASS"));
                curl_setopt($ch[$j], CURLOPT_URL, $url);

                curl_multi_add_handle($mh,$ch[$j]);
              }
            }

            do
            {
              $status = curl_multi_exec($mh, $active);
              
              if ($active) { curl_multi_select($mh); }
                  
              // echo "Waiting ".CURLM_OK."(A=$active,S=$status)<BR>\n";
            } while ($active && $status == CURLM_OK);

            for ($j=0;$j<sizeof($data_vigrid['GNS3'][$ip_address]['PROJECTS']);$j++)
            {
              $data_json=json_decode(curl_multi_getcontent($ch[$j]),true);
              
              if (!is_null($data_json))
              {
                $data_vigrid['GNS3'][$ip_address]['PROJECT_NODES'][$data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['project_id']]['NODES']=$data_json;
                // alpha sort nodes...
                usort($data_vigrid['GNS3'][$ip_address]['PROJECT_NODES'][$data_vigrid['GNS3'][$ip_address]['PROJECTS'][$j]['project_id']]['NODES'], 'compare_name');
              }

              curl_multi_remove_handle($mh, $ch[$j]);
            }

            curl_multi_close($mh);

            $done[$i]=1;
          }
        }
      }

      // Delay management
      // 50ms wait, max 8 times (400ms total) + delay to get the info.
      // Since getting the info takes time we should not loose again, after 500ms passed, a last turn to finish

      $micro_time_current=microtime(true);
          
      if (($attempts++>15) || ($done_all==1)) { break; } // 3000ms max delay are enough, or job done
      else if ($micro_time_current-$micro_time_start>3) { $attempts=20; } // 2500ms already passed, enough ! a last turn
      else { usleep(200000); }
    }

    error_reporting($current_error);
    
    return($data_vigrid);
  }

  function VIGRIDparam_getdesc()
  {
    $vigrid_config_desc="/home/gns3/vigrid/etc/vigrid_config.json";

    // Loading descriptions
    $t=file_get_contents($vigrid_config_desc);
    if ($t) { return(json_decode($t,true)); }

    return(null);
  }

  function VIGRIDparam_getform($vigrid_params_desc,$param_name)
  {
    for ($p=0;$p<sizeof($vigrid_params_desc);$p++)
    {
      if ($vigrid_params_desc[$p]['NAME']==$param_name)
      { return($vigrid_params_desc[$p]['FORM']); }
    }
    return(null);
  }
  
  function VIGRIDconfig($var_wanted)
  {
    $config_file="/home/gns3/etc/vigrid.conf";
    
    if ($var_wanted=="") { return(""); }
    
    $fd=fopen($config_file,"r");
    if (!$fd) { print("Cant open $config_file !!, stopping\n"); exit; }
    while (($line = fgets($fd, 4096)) !== false)
    {
      // Lines are shell variables (var=value, var="value", var='value')
      $line=trim($line);
      
      $f=explode("=",$line);

      $var_name=$f[0];
      $var_name=preg_replace("/[\s ]*/","",$var_name);
      $var_name=preg_replace("/[#;].*$/","",$var_name);

      array_shift($f);
      $var_value=implode("=",$f);
      
      if ($var_name==$var_wanted) // Real var, extracting value
      {
        // Clean var
        $var_value=preg_replace("/^[\"']/","",$var_value);
        $var_value=preg_replace("/[\"']$/","",$var_value);

        if (VIGRIDparam_getform(VIGRIDparam_getdesc(),$var_name)=="PASS") // passwords are partially escaped due to shell
        {
          $var_value=str_replace("\\\\","\\",$var_value);
          $var_value=str_replace("\\\"","\"",$var_value);
        }
        # Vigrid Hosts always include Master
        elseif (strcasecmp($var_name,"VIGRID_GNS_SLAVE_HOSTS")==0)
        {
          # hostname:IPaddress:port
          $_tmp_gns_server=gns_getserver_config();
          $var_ip=$_tmp_gns_server['host'];

          if ($var_ip=="")
          { $var_ip=gethostbyname(gethostname()); }

          if ($var_ip=="") { $var_value=gethostname().":127.0.0.1:3080 ".$var_value; }
          else { $var_value=gethostname().":$var_ip:3080 ".$var_value; }
        }

        fclose($fd);
        return($var_value);
      }
    }
    fclose($fd);
    return("");
  }

	function VIGRIDssh_check($hostname,$sshkey,$user)
	{
    if (($hostname=="") || ($sshkey=="") || ($user=="")) { return(-1); }
    
    $fd=popen("sudo -u gns3 /home/gns3/vigrid/bin/vigrid-sshcheck -h $hostname -s \"$sshkey\" -u $user","r");
    $rc=pclose($fd);
    
    return($rc);
  }
  
  function gen_uuid()
  {
    return sprintf( '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
      // 32 bits for "time_low"
      random_int( 0, 0xffff ), random_int( 0, 0xffff ),
      // 16 bits for "time_mid"
      random_int( 0, 0xffff ),
      // 16 bits for "time_hi_and_version",
      // four most significant bits holds version number 4
      random_int( 0, 0x0fff ) | 0x4000,
      // 16 bits, 8 bits for "clk_seq_hi_res",
      // 8 bits for "clk_seq_low",
      // two most significant bits holds zero and one for variant DCE1.1
      random_int( 0, 0x3fff ) | 0x8000,
      // 48 bits for "node"
      random_int( 0, 0xffff ), random_int( 0, 0xffff ), random_int( 0, 0xffff )
    );
  }

  function VIGRIDgetgnshosturl($gns_controller,$hostname,$endpoint)
  {
    $url="";

    $vigrid_hosts=VIGRIDgetgnshosts($gns_controller);
    
    if ($hostname!="")
    {
      $hostnum=gns_gethostnumbyname($gns_controller,$hostname);
      if ($hostnum==-1)
      {
        // Maybe host IP was given instead of name, try another way
        $hostnum=gns_gethostnumbyip($gns_controller,$hostname);
      }
    }
    
    if (($hostnum==-1) || ($hostname=="")) // Not a host already in a controller, probably a Vigrid host then
    {
      for ($i=0;$i<sizeof($vigrid_hosts);$i++)
      {
        $f=explode(":",$vigrid_hosts[$i]);
        $ip_name=$f[0];
        $ip_address=$f[1];
        $ip_port=$f[2];
        $ip_compute=$f[3];
        
        if (($ip_name==$hostname) || ($ip_address==$hostname)) // Yessss !
        { $url="http://".$ip_address.":".$ip_port.$endpoint; break; }
      }
    }
    else 
    { $url=$gns_controller['computes'][$hostnum]['protocol']."://".$gns_controller['computes'][$hostnum]['host'].":".$gns_controller['computes'][$hostnum]['port'].$endpoint; }
  
    return($url);
  }    

  function VIGRIDget_translation_url($wanted_gnsip,$wanted_gnsport)
  {
    $translation_file="/home/gns3/etc/vigrid-translation-table.conf";
    
    if (($wanted_gnsip=="") || (($wanted_gnsport<1) || ($wanted_gnsport>65535))) { return(""); }
    
    $fd=fopen($translation_file,"r");
    if (!$fd) { print("Cant open $translation_file !!\n"); return(""); }
    while (($line = fgets($fd, 4096)) !== false)
    {
      // Lines are: GNS_IP:GNS_PORT=URL_WITH_FQDN
      $line=trim($line);
      
      $f=explode(":",$line);
      $var_gnsip=$f[0];

      $t=explode("=",$f[1]);
      $var_gnsport=$t[0];

      $f=explode("=",$line);
      $var_gnsurl=$f[1];

      if (($var_gnsip==$wanted_gnsip) && ($var_gnsport==$wanted_gnsport)) // Matching GNS IP+port, extract URI
      {
        fclose($fd);
        return($var_gnsurl);
      }
    }
    fclose($fd);
    return("");
  }
?>
