<?php

function API_load($json_array,$filters_net,$filters_dir)
{
  $json_array['hostname']=gethostname();

  // Get last lines from /var/log/vigrid-load.log
  $load_array=VigridLOADextract('/var/log/vigrid-load.log');
  
  // Get associated CPU values
  $cpu=VigridLOADgetcpu($load_array);

  $json_array['nproc']=$cpu['nproc'];
  
  $json_array['cpuload']['1m']=$cpu['load1']."/".$cpu['load_perf1']."%";
  $json_array['cpuload']['5m']=$cpu['load5']."/".$cpu['load_perf5']."%";
  $json_array['cpuload']['15m']=$cpu['load15']."/".$cpu['load_perf15']."%";

  $json_array['cpuload']['avg']=$cpu['cpu_load']."%";
  $json_array['cpu-iowaits']['avg']=$cpu['cpu_wa']."/".$cpu['cpu_wa_perf']."%";

  $ram_data=getSystemMemInfo();
  $json_array['ram']=$ram_data['MemFree']."/".$ram_data['MemTotal'];
  $json_array['swap']=$ram_data['SwapFree']."/".$ram_data['SwapTotal'];

  // Get associated NET values
  $nets=VigridLOADgetnet($load_array,$filters_net);

  foreach($nets as $names => $net_cur)
  {
    $rate_in=HumanSize($net_cur['bytes_in']);
    $rate_out=HumanSize($net_cur['bytes_out']);
    
    $max_in =HumanSize($net_cur['bytes_in_max']);
    $max_out=HumanSize($net_cur['bytes_out_max']);
    
    { $json_array['net'][$names]="$rate_out/$max_out/$rate_in/$max_in/".$net_cur['speed']; }
  }
  
  if (!empty($filters_dir))
  {
    foreach ($filters_dir as $dir)
    {
      if (file_exists($dir) && is_dir($dir))
      {
        $disk_free =HumanSize(disk_free_space($dir));
        $disk_total=HumanSize(disk_total_space($dir));
        
        // to determine which device is below directory
        // 1- get btrfs/ZFS dataset for this directory
        // 2- extract top level pool for this dataset
        // 3- get device for this pool
        $disk_dev="";

        $json_array['dir'][$dir]['space']="$disk_free/$disk_total";
        $json_array['dir'][$dir]['mount']=$disk_dev;
     }
    }
  }

  if ($json_array) { echo json_encode($json_array); }
  return;
}

function generateRandomString($length)
{
  return substr(str_shuffle(str_repeat($x='0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', ceil($length/strlen($x)) )),1,$length);
}

function getSystemMemInfo() 
{       
  $data = explode("\n", file_get_contents("/proc/meminfo"));
  $meminfo = array();
  foreach ($data as $line) {
      list($key, $val) = explode(":", $line);
      $meminfo[$key] = strtoupper(preg_replace("/ /","",trim($val)));
  }
  return $meminfo;
}

function HumanSize($Bytes)
{
  $Type=array("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB");
  $Index=0;
  
  while($Bytes>=1024)
  {
    $Bytes/=1024;
    $Index++;
  }
  
  $t=sprintf("%.02f".$Type[$Index],$Bytes);
  
  if (intval($t)==$Bytes)
  { $t=sprintf("%d".$Type[$Index],$Bytes); }

  return ($t);
}

?>
