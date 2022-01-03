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
	// emqx API functions
  
  function URLget($username,$password,$url)
  {
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);

    curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
    if (($username!="") || ($password!=""))
		{ curl_setopt($ch, CURLOPT_USERPWD, $username.":".$password); }

		curl_setopt($ch, CURLOPT_URL, $url);

		$output=curl_exec($ch);
		curl_close($ch);

    return($output);
  }
	
	function EMQXgetghosts($username,$password,$emqx_server)
	{
    $url="$emqx_server/api/v4/clients";
    $ghosts_json=URLget($username,$password,$url);

		$ghosts=json_decode($ghosts_json,true);
		return($ghosts);
	}

	function URLpost($username,$password,$url,$post_data)
	{
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
		curl_setopt($ch, CURLOPT_POST, true);

    if (($username!="") || ($password!=""))
		{ curl_setopt($ch, CURLOPT_USERPWD, $username, $password); }

		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_POSTFIELDS,$post_data);
    
		$output=curl_exec($ch);
		curl_close($ch);

		return ($output);
	}

	function EMQXaction($gns_controller,$hostname,$project_id)
	{
		$hostnum=gns_gethostnumbyname($gns_controller,$hostname);
		if ($hostnum==-1) { return(null); }

		$url=$gns_controller['computes'][$hostnum]['protocol']."://".$gns_controller['computes'][$hostnum]['host'].":".$gns_controller['computes'][$hostnum]['port']."/v2/projects/".$project_id;
		// print("URL=$url\n");
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
		// curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "DELETE");
		curl_setopt($ch, CURLOPT_USERPWD, $gns_controller['computes'][$hostnum]['user'].":".$gns_controller['computes'][$hostnum]['password']);
		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_POSTFIELDS, "{}");
		$json=curl_exec($ch);
		curl_close($ch);

		return ($json);
	}	
?>
