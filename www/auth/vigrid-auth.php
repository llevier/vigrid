<?php

// GNS3 access control

// Must filter upon:
//  $url_method (GET/PUT/POST)
//  $http_auth (Authorization header)
//  /projects/uuid/
//  /nodes/uuid/
//  /links/uuid/

$debug=1;

$url_host=(isset($_SERVER['HTTPS']) ? "https" : "http") . "://$_SERVER[HTTP_HOST]";
$url_method=$_SERVER['REQUEST_METHOD'];
$url_path=$_SERVER['REQUEST_URI'];
$url_called="$url_host"."$url_path";

// $actual_link = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";

// Debug($debug,"\n*** Called URL: $url_method $url_called\n");
// Debug($debug,"    LINK=$actual_link\n");

if (!function_exists('getallheaders'))
{
        // Debug($debug,"    WARNING: getallheaders() does not exist !!\n");

        function getallheaders()
        {
                $headers = [];

                foreach ($_SERVER as $name => $value)
                {
                        if ((substr($name, 0, 5) == 'HTTP_') || (substr($name, 0, 6) == 'HTTPS_'))
                        { $headers[str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($name, 5)))))] = $value; }
                      else
                      { $headers[$name]=$value; }
                }
                foreach ($headers as  $name => $value) { Debug($debug,"N=$name, V=$value\n"); }
                return $headers;
        }
}

// Who calls ? GNS3 client (/GNS3 QT Client v/) or anything else ?
// Extract headers so it is done
$headers=[];
$headers=getallheaders();

Debug($debug,"\n    \$_SERVER:\n");
foreach ($_SERVER as $key => $value) { Debug($debug,"      $key => $value\n"); }
Debug($debug,"\n");

Debug($debug,"\n    Received headers:\n");
foreach ($headers as $key => $value) { Debug($debug,"      $key => $value\n"); }
Debug($debug,"\n");

if (isset($headers['X-Forwarded-Scheme'])) { $to_validate_scheme=$headers['X-Forwarded-Scheme']; }
else { $to_validate_scheme=(isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http"); }

$to_validate_host=$headers['X-Original-Host'];
$to_validate_url=$headers['X-Original-Uri'];

if (isset($headers['X-Forwarded-Method'])) { $to_validate_method=$headers['X-Forwarded-Method']; }
else { $to_validate_method=$_SERVER['REQUEST_METHOD']; }

Debug($debug,"\n*** Called URL: $to_validate_method $to_validate_scheme://$to_validate_host$to_validate_url\n");

if  (($to_validate_method=="OPTIONS")
 || (($headers['Access-Control-Request-Method']=='GET') && ($headers['Access-Control-Request-Headers']=='authorization'))
 || ($headers['Sec-Fetch-Mode']=='cors'))
{
  // CORS request
  $http_origin=$headers['Origin'];
  Debug($debug,"\n*** CORS request call from $http_origin !\n");

  include "/home/gns3/vigrid/www/site/manager/vigrid-gns3_functions.php";

  $cors_allow_origin=preg_split("/,/",trim(strtolower(VIGRIDconfig('VIGRID_CORS_ALLOW_ORIGIN'))));
  Debug($debug,"    CORS allow origin=".implode("-",$cors_allow_origin)."\n");

  $cors_allow="";
  
  if ($http_origin!="")
  {
    foreach ($cors_allow_origin as $host_pattern)
    {
      Debug($debug,"    CORS Origin=$http_origin, pattern=$host_pattern\n");
      if (preg_match("/".$host_pattern."/",$http_origin) || ($host_pattern=='*'))
      { Debug($debug,"    CORS match, allowing $http_origin\n"); $cors_allow=$http_origin; break; }
    }
  }

  header('Access-Control-Allow-Origin: *'); // .$cors_allow);
  header('Access-Control-Allow-Credentials: true');
  header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
  header('Access-Control-Allow-Headers: Accept,Authorization,Cache-Control,Content-Type,DNT,If-Modified-Since,Keep-Alive,Origin,User-Agent,X-Requested-With');

  if (($headers['Access-Control-Request-Method']=='GET') && ($headers['Access-Control-Request-Headers']=='authorization'))
  { return 204; }
}

// Lets extract credentials now
$http_user="";
$http_pass="";

if (isset($headers['Authorization']))
{
  $http_auth=preg_replace("/^.* /","",$headers['Authorization']);
  $http_auth=base64_decode($http_auth);
  $t=preg_split("/:/",$http_auth);
  $http_user=$t[0];
  $http_pass=$t[1];
}

Debug($debug,"    Identified user: ");
if ($http_user!="")
{ Debug($debug,"$http_user ($http_pass)\n"); }
else
{ Debug($debug,"UNKNOWN\n"); }

####### Extract associated data ######
if ($to_validate_method=='GET')
{
  if (isset($_GET)) { Debug($debug,"    GET values:\n    ".print_r($_GET, true)."\n"); }
  else { Debug($debug,"    GET values: none\n"); }
}
else if (($to_validate_method=='POST') || ($to_validate_method=='PUT') || ($to_validate_method=='DELETE'))
{
  parse_str(file_get_contents("php://input"),$data);
  Debug($debug,"    POST/PUT/DELETE values:\n    ".print_r($data, true)."\n");
}

##################################################### SECURITY CONTROL ####################################################

### CONSOLE DETECTION: /noTELNET/port/ or /noVNC/port/
if (preg_match("/\/noVNC\/[0-9]*\//",$to_validate_url) || (preg_match("/\/noTELNET\/[0-9]*\//",$to_validate_url)))
{
  Debug($debug,"    Console access detection, ");
  $t=preg_replace("/^.*\/no(VNC|TELNET)\//","",$to_validate_url);
  $console_port=preg_replace("/^.*$/","",$to_validate_url);
  $t=preg_split("/\//",$t);
  $console_port=$t[0];
  
  $t=preg_replace("/\/$console_port\/.*$/","",$to_validate_url);
  $console_type=preg_replace("/^.*\/no/","",$t);
  // $console_type=$t;
  Debug($debug,"($console_type) port=$console_port\n");
}

##################################################### ACCESS CONTROL ####################################################
if (!isAcceptable(true)) // permitted to pass ?
{ Reject(); }

// Get GNS3 IP/login/pass
if (!$fd_gns=fopen("/home/gns3/.config/GNS3/gns3_server.conf","r"))
{ print("Cant open server config file"); exit; }

$gns_user="";
$gns_pass="";
while (!feof($fd_gns))
{
  $line=fgets($fd_gns,4096);

  $line=trim($line);
  $line=preg_replace("/;.*$/","",$line);

  if ((preg_match("/^user/",$line)) || (preg_match("/^password/",$line)))
  {
    $line=preg_replace("/[\s ]+/"," ",$line);
    $f=array_map('trim',preg_split("/=/",$line));

    if ($f[0]=="user") { $gns_user=$f[1]; }
    elseif ($f[0]=="password") { $gns_pass=$f[1]; }
  }
}
fclose($fd_gns);

### GNS3client auth change hack to add basic access control
# [User-Agent] => GNS3 QT Client v2.2.21
# Also for /manager/vigrid-env.html page (troubleshoot)
if ((isset($headers['User-Agent']) && (preg_match("/GNS3 QT Client/",$headers['User-Agent'])))
 || (preg_match("/\/manager\/vigrid-env.html$/",$to_validate_url))
# Hack because sometimes User-Agent vanishes with Heavy client.
 || (preg_match("/^\/v[23]\//",$to_validate_url) && (isset($headers['Sec-Websocket-Version']) || isset($headers['Sec-Websocket-Key']))))
{
  Debug($debug,"    GNS3 Client detected, changing Authorization header\n");

  $hash=base64_encode("$gns_user:$gns_pass");
  Debug($debug,"      GNS3 Auth ($gns_user / $gns_pass) = $hash\n\n");
  $headers['Authorization']="Basic $hash";
  header("Authorization: Basic $hash",1);
}

Debug($debug,"    -> Access granted, sending 200\n");
exit;

function Reject()
{
  global $debug;

  $http_status_codes = [100 => "Continue", 101 => "Switching Protocols", 102 => "Processing", 200 => "OK", 
    201 => "Created", 202 => "Accepted", 203 => "Non-Authoritative Information", 204 => "No Content",
    205 => "Reset Content", 206 => "Partial Content", 207 => "Multi-Status", 300 => "Multiple Choices",
    301 => "Moved Permanently", 302 => "Found", 303 => "See Other", 304 => "Not Modified", 305 => "Use Proxy",
    306 => "(Unused)", 307 => "Temporary Redirect", 308 => "Permanent Redirect", 400 => "Bad Request",
    401 => "Unauthorized", 402 => "Payment Required", 403 => "Forbidden", 404 => "Not Found",
    405 => "Method Not Allowed", 406 => "Not Acceptable", 407 => "Proxy Authentication Required",
    408 => "Request Timeout", 409 => "Conflict", 410 => "Gone", 411 => "Length Required", 412 => "Precondition Failed",
    413 => "Request Entity Too Large", 414 => "Request-URI Too Long", 415 => "Unsupported Media Type",
    416 => "Requested Range Not Satisfiable", 417 => "Expectation Failed", 418 => "I'm a teapot", 419 => "Authentication Timeout",
    420 => "Enhance Your Calm", 422 => "Unprocessable Entity", 423 => "Locked", 424 => "Failed Dependency",
    424 => "Method Failure", 425 => "Unordered Collection", 426 => "Upgrade Required", 428 => "Precondition Required",
    429 => "Too Many Requests", 431 => "Request Header Fields Too Large", 444 => "No Response", 449 => "Retry With",
    450 => "Blocked by Windows Parental Controls", 451 => "Unavailable For Legal Reasons", 494 => "Request Header Too Large",
    495 => "Cert Error", 496 => "No Cert", 497 => "HTTP to HTTPS", 499 => "Client Closed Request",
    500 => "Internal Server Error", 501 => "Not Implemented", 502 => "Bad Gateway", 503 => "Service Unavailable",
    504 => "Gateway Timeout", 505 => "HTTP Version Not Supported", 506 => "Variant Also Negotiates",
    507 => "Insufficient Storage", 508 => "Loop Detected", 509 => "Bandwidth Limit Exceeded", 510 => "Not Extended",
    511 => "Network Authentication Required", 598 => "Network read timeout error", 599 => "Network connect timeout error"];

  $response_code=403;
  Debug($debug,"    -> Access rejected, exiting/sending $response_code ($http_status_codes[$response_code])\n");
  // print($response_code.' '.$http_status_codes[$response_code]);
  header($_SERVER['SERVER_PROTOCOL'].' '.$response_code.' '.$http_status_codes[$response_code]);

  exit;
}

function Debug($level,$text)
{
        // return;

  if ($level==0) { return; }
  
        if (!$fd_log=fopen("/tmp/vigrid-auth.log","a+"))
        { print("Cant open/create /tmp/vigrid-auth.log file"); }

        fwrite($fd_log,$text);
        fclose($fd_log);
}

function isAcceptable($value)
{
  global $debug,$http_user,$http_pass;
  
  Debug($debug,"    Checking right access for $http_user ($http_pass) from /home/gns3/etc/vigrid-passwd...\n");
  if (!$fd=fopen("/home/gns3/etc/vigrid-passwd","r"))
  { return(0); }

  while (!feof($fd))
  {
    $line=fgets($fd,1000);
    $line=chop($line);
    $line=ltrim($line);
    $line=preg_replace("/:{PLAIN}/",":",$line);
    Debug($debug,"      Got user: $line\n");
    
    if (($line!="") && ($line=="$http_user:$http_pass"))
    {
      Debug($debug,"        USERS match: $line vs $http_user:$http_pass\n");
      return (1);
    }
  }
  
  fclose($fd);
  
        return(0); # bad value
}
?>
