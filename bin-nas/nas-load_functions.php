<?php

// #################################################################################################################################
// #
// # This material is part of VIGRID extensions to GNS3 for Trainings & CyberRange designs
// #
// # (c) Laurent LEVIER for script, designs and technical actions, https://github.com/llevier/
// # LICENCE: Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA)
// #
// # Each dependancies (c) to their respective owners
// #
// ##################################################################################################################################

if (!function_exists('get_exec'))
{
  function get_exec($command,$prefix,$display)
  {
    $res=array();

    $fd=popen("$command 2>&1","r");
    while (!feof($fd))
    {
      $line=fgets($fd,4096);
      array_push($res,$line);
      if ($display) { report(0,$prefix.$line); ob_implicit_flush(); }
    }
    $rc=pclose($fd);
    
    return(array($rc,$res));
  }
}

// Extract dev from directory
function VigridGETdev($directory)
{
  if (empty($directory)) return (NULL);
  
  # First Try to identify ZFS pool
  list($rc,$res)=get_exec("zfs mount","",false);
  $res=preg_replace("/[\n\r]$/","",$res);
  
  // Extract storage
  $storage_regex=preg_replace("/\//","\\\/",$directory);
  $zfs_pool=preg_grep("/$storage_regex$/",$res);
  $zfs_pool=array_values($zfs_pool);
  // Now I got it, take the first part (ZFS pool, sub parts are datasets)
  $zfs_pool=preg_replace("/\/.*$/","",$zfs_pool[0]);
  $zfs_pool=preg_replace("/\s+.*$/","",$zfs_pool);

  if ($verbose==1) { print ("Vigrid Storage Root pool is $zfs_pool\n"); }

  list($rc,$res)=get_exec("zpool status -P $zfs_pool","",false);
  $disks_array=preg_grep("/\/dev\//",$res);
  $disks_array=preg_replace("/^.*\/dev\//","",$disks_array);
  $disks_array=preg_replace("/\s+.*$/","",$disks_array);
  
  return($disks_array);
}

// Get CPU values from vigrid-load data.
function VigridLOADgetcpu($load_array)
{
  if ($load_array==NULL) return;
  
  $cpu=array();
  
  // CPU stats
  $cpu_line=array_values(preg_grep("/ cpu [0-9]/",$load_array));
  $cpu_fields=preg_split("/\s+/",$cpu_line[0]);

  // $date C cpu $nproc $load1 $load_perf1 $load5 $load_perf5 $load15 $load_perf15 $disp_diff_cpu_load $diff_cpu_wa $disp_diff_cpu_wa
  $cpu['nproc']=$cpu_fields[3];
  
  $cpu['load1']=sprintf("%2.2f",$cpu_fields[4]);
  $cpu['load_perf1']=$cpu_fields[5];
  $cpu['load5']=sprintf("%2.2f",$cpu_fields[6]);
  $cpu['load_perf5']=$cpu_fields[7];
  $cpu['load15']=sprintf("%2.2f",$cpu_fields[8]);
  $cpu['load_perf15']=$cpu_fields[9];

  $cpu['cpu_load']=$cpu_fields[10];
  $cpu['cpu_wa']=$cpu_fields[11];
  $cpu['cpu_wa_perf']=$cpu_fields[12];
  
  return($cpu);
}
  
function VigridLOADgetdisk($load_array,$filters_disk)
{
  if ($load_array==NULL) return;

  $disk=array();
  
  for ($i=0;$i<sizeof($load_array);$i++)
  {
    $f=preg_split("/\s+/",$load_array[$i]);

    if (((!empty($filters_disk)) && (preg_grep("/^$f[2]$/",$filters_disk)))
     || ((empty($filters_disk)) && ($f[1]=="D")))
    {
      $name=$f[2];

      $disk[$name]['time']=$f[0];
      $disk[$name]['out']=sprintf("%d",$f[2]);
      $disk[$name]['in']=sprintf("%d",$f[3]);

      $disk[$name]['rs']             =sprintf("%d",$f[3]);
      $disk[$name]['rs_max']         =sprintf("%d",$f[4]);
      $disk[$name]['rsect']          =sprintf("%d",$f[5]);
      $disk[$name]['rsect_max']      =sprintf("%d",$f[6]);

      $disk[$name]['ws']             =sprintf("%d",$f[7]);
      $disk[$name]['ws_max']         =sprintf("%d",$f[8]);
      $disk[$name]['wsect']          =sprintf("%d",$f[9]);
      $disk[$name]['wsect_max']      =sprintf("%d",$f[10]);

      $disk[$name]['io_pending']     =sprintf("%d",$f[11]);
      $disk[$name]['io_pending_max'] =sprintf("%d",$f[12]);
    }
  }
  return($disk);
}  

function VigridLOADgetnet($load_array,$filters_net)
{
  if ($load_array==NULL) return;

  $net=array();
  
  for ($i=0;$i<sizeof($load_array);$i++)
  {
    $f=preg_split("/\s+/",$load_array[$i]);
    
    if (((!empty($filters_net)) && (preg_grep("/^$f[2]$/",$filters_net)))
     || ((empty($filters_net)) && ($f[1]=="N")))
    {
      $name=$f[2];
      
      $net[$name]['bytes_in']=$f[3];
      $net[$name]['bytes_in_max']=$f[4];
      $net[$name]['bytes_out']=$f[5];
      $net[$name]['bytes_out_max']=$f[6];
      
      // Get NIC speed as well
      if ($net[$name]['speed']==0)
      {
        $t=file("/sys/class/net/$name/speed");
        $net[$name]['speed']=trim($t[0]);
      }
    
      if ($net[$name]['speed']=="") // bridge_port(s)
      {
        $wd_cur=getcwd();
        chdir("/sys/class/net/$name/");
        
        // List lower(s), extract min speed as default value
        $value_min=0;
        foreach (glob("lower_*") as $filename)
        {
          if (!preg_match("/gns3/",$filename)) // Ignoring GNS3 taps
          {
            $t=file("/sys/class/net/$name/$filename/speed");
            
            $name_lower=preg_replace("/lower_/","",$filename);
           
            if ($value_min==0) { $value_min=trim($t[0]); }
            else if ($t[0]<$value_min) { $value_min=trim($t[0]); }
            
            $net[$name_lower]['speed']=$value_min;
          }
        }
        $net[$name]['speed']=$value_min;
        
        chdir($wd_cur);
      }
    }
  }
  
  return($net);
}

function VigridLOADextract($filename)
{
  $load_array=array();
  
  $t=explode(PHP_EOL,shell_exec("tail -20 $filename"));
  
  $mark_end=-1;
  $mark_start=-1;
  
  for ($i=sizeof($t);$i>0;$i--)
  {
    if (preg_match("/ cpu [0-9]/",$t[$i]))
    {
      $f=preg_split("/\s+/",$t[$i]);
      if (sizeof($f)==13)
      {
        if ($mark_end==-1) { $mark_end=$i; }
        else if ($mark_start==-1)
        {
          $mark_start=$i+1;
          break;
        }
      }
    }
  }

  if (($mark_start!=-1) && ($mark_end!=-1))
  {
    for ($i=$mark_start;$i<=$mark_end;$i++)
    { array_push($load_array,$t[$i]); }
  }

  return($load_array);
}
