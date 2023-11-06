#!/bin/sh
#################################################################################################################################
#
# This material is part of VIGRID extensions to GNS3 for Trainings & CyberRange designs
#
# (c) Laurent LEVIER for script, designs and technical actions, https://github.com/llevier/
# LICENCE: Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA)
#
# Each dependancies (c) to their respective owners
#
#################################################################################################################################

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# To have script execution traced...
SCRIPT_NAME=`basename $0`
LOG_FILE="/tmp/$SCRIPT_NAME-log.out"

PROG_ARG=$1

VIGRID_CONF="/home/gns3/etc/vigrid.conf"

#
# Functions
#

# Error display & management
Error()
{
  TXT=$*
  
  until false
  do
    echo
    echo -n "$TXT do you wish to (F)orce continue, (C)ontinue/(R)un a sub shell/(E)xit script [F/C/R/E) ? "
    read ANS
    
    case "$ANS" in
      f|F)
        return 2
        ;;
      c|C)
        return 1
        ;;
      r|R)
        echo "Launching /bin/sh via script command. Output will be added to the log file"
        echo "Once you finished, end with the 'exit' command."
        echo
        # script /bin/sh /tmp/shell-$$.log
        /bin/sh -xi
        
        # echo "Concatening shell output to log file..."
        # cat /tmp/shell-$$.log >>$LOG_FILE
        # rm /tmp/shell-$$.log
        TXT="Shell ended,"
        ;;
      e|E)
        echo "Ok. bye bye then..."
        exit 1
        ;;
    esac
  done
}

Display()
{
  NO_CR=0
  NO_HEAD=0
  
  until false
  do
    case "$1" in
      "-n")
        NO_CR=1
        shift
        ;;
      "-h")
        NO_HEAD=1
        shift
        ;;
      *)
        TXT=$*
        break
        ;;
    esac
  done

  [ $NO_HEAD -eq 0 ] && echo && echo "############# VIGRID DISPLAY ################################################################"

  [ $NO_HEAD -eq 0 ] && echo -n "# "
  
  [ $NO_CR -eq 0 ] && echo "$TXT" && echo
  [ $NO_CR -eq 1 ] && echo -n "$TXT"
  
  return 0
}

#
# Script starts
#

rm -f $LOG_FILE 2>/dev/null
(
# Part of script to run on Master
if [ "x$PROG_ARG" = "x" ]
then
  Display ""
  Display -h -n "
Vigrid update script: Add Vigrid-API to slaves.

This script requires to be launched via the vigrid-run command to all/targetted slaves, so Vigrid configuration must be accurate.

Upon any issue, script will pause, proposing to (force) continue, run a sub shell or exit procedure.
Everything will be logged to $LOG_FILE.

Upon any question with default answer, validate the choice.
IMPORTANT: if this server is using DHCP, I'll set the IP address to the one obtained. This IP might change in the future,
especially if you select CyberRange designs.

#############################################################################################

Press [RETURN] to start..."

  read ANS

  Display -n -h "
First, do you wish to change [BACKSPACE], sometimes there are some issues with terminals... [y/N] ? "
  read ANS

  if [ "x$ANS" = "xy" -o "x$ANS" = "xY" ]
  then
    Display -h -n "Ok, now just press [BACKSPACE] then [RETURN] "
    read ANS
    stty erase $ANS 2>/dev/null
    Display -h "[BACKSPACE] set now."
  fi

  SCRIPT_CWD=`/usr/bin/pwd`
  [ "x$SCRIPT_CWD" = "x" ] && Display "I cant find where I am, exiting" && exit 1

  # Sanity checks
  Display "Ok, let's start..."

  Display "Adding entries on Vigrid Master NGinx configuration"
  
  . /home/gns3/etc/vigrid.conf
  if [ $? -ne 0 ]
  then
    Error 'Cant load /home/gns3/etc/vigrid.conf,'
    exit 1
  fi
  
  # Adding Vigrid-NAS to NGinx
  if [ "x$VIGRID_NAS_SERVER" != "x" ]
  then
    NAME=`echo $VIGRID_NAS_SERVER | awk 'BEGIN { FS=":"; } { print $1; }'`
    HOST=`echo $VIGRID_NAS_SERVER | awk 'BEGIN { FS=":"; } { print $2; }'`
    
    Display -h "    Generating NGinx configuration for Vigrid-NAS ($HOST)"
    echo "#
# Vigrid HTTPS access for NAS
#
server {
  listen 127.0.0.1:443 ssl;
  server_name $NAME;

  # Take fullchain here, not cert.pem
  ssl_certificate      /etc/nginx/ssl/localhost.crt;
  ssl_certificate_key  /etc/nginx/ssl/localhost.key;

  ssl_session_cache    builtin:1000 shared:SSL:1m;
  ssl_session_timeout  5m;

  ssl_protocols   TLSv1.2 TLSv1.3;
  ssl_ciphers  HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers  on;

  # hide version
  server_tokens        off;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  # Vigrid API
  location /vigrid-api
  {
    rewrite ^/vigrid-nas-api/(.*)\$ /vigrid-nas-api.html?order=\$1 break;

    proxy_pass https://$HOST;

    proxy_pass_request_body on;

    proxy_set_header Host \$host;
    proxy_set_header Authorization \$auth_header;

    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"Upgrade\";
  }

  location = /auth
  {
    internal;
    
    proxy_pass             http://localhost:8001;
    proxy_pass_request_body off;
    
    proxy_set_header        Content-Length \"\";
    proxy_set_header        X-Original-URI \$request_uri;
    proxy_set_header        X-Original-Host \$host;
    proxy_set_header        X-Real-IP \$remote_addr;
    proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header        X-Forwarded-Host \$server_name;  
  }
}
}" >/etc/nginx/conf.d/CyberRange-$NAME-443.conf
  fi  
  
  for i in $VIGRID_GNS_SLAVE_HOSTS
  do
    NAME=`echo $i | awk 'BEGIN { FS=":"; } { print $1; }'`
    HOST=`echo $i | awk 'BEGIN { FS=":"; } { print $2; }'`
    PORT=`echo $i | awk 'BEGIN { FS=":"; } { print $3; }'`

    Display -h "    Generating NGinx configuration for $HOST"
    echo "#
# Vigrid HTTPS access for Extensions + GNS3 Heavy client
#
server {
  listen 127.0.0.1:443 ssl;
  server_name $NAME;

  # Take fullchain here, not cert.pem
  ssl_certificate      /etc/nginx/ssl/localhost.crt;
  ssl_certificate_key  /etc/nginx/ssl/localhost.key;

  ssl_session_cache    builtin:1000 shared:SSL:1m;
  ssl_session_timeout  5m;

  ssl_protocols   TLSv1.2 TLSv1.3;
  ssl_ciphers  HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers  on;

  # hide version
  server_tokens        off;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  # Vigrid API
  location /vigrid-api
  {
    rewrite ^/vigrid-api/(.*)\$ /vigrid-host-api.html?order=\$1 break;

    proxy_pass https://$HOST;

    proxy_pass_request_body on;

    proxy_set_header Host \$host;
    proxy_set_header Authorization \$auth_header;

    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"Upgrade\";
  }

  # GNS Heavy client
  location /v2
  {
    auth_request     /auth;
    auth_request_set \$auth_status \$upstream_status;
    auth_request_set \$auth_header \$upstream_http_authorization;

    proxy_set_header Host \$host;
    proxy_set_header Authorization \$auth_header;

    # GNS3 maximum timeout = 1h
    proxy_connect_timeout       3600;
    proxy_send_timeout          3600;
    proxy_read_timeout          3600;
    send_timeout                3600;

    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"Upgrade\";

    proxy_pass http://$HOST:$PORT;
  }

  # GNS Heavy client
  location /v3
  {
    auth_request     /auth;
    auth_request_set \$auth_status \$upstream_status;
    auth_request_set \$auth_header \$upstream_http_authorization;

    proxy_set_header Host \$host;
    proxy_set_header Authorization \$auth_header;

    # GNS3 maximum timeout = 1h
    proxy_connect_timeout       3600;
    proxy_send_timeout          3600;
    proxy_read_timeout          3600;
    send_timeout                3600;

    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"Upgrade\";

    proxy_pass http://$HOST:$PORT;
  }

  location = /auth
  {
    internal;
    
    proxy_pass             http://localhost:8001;
    proxy_pass_request_body off;
    
    proxy_set_header        Content-Length \"\";
    proxy_set_header        X-Original-URI \$request_uri;
    proxy_set_header        X-Original-Host \$host;
    proxy_set_header        X-Real-IP \$remote_addr;
    proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header        X-Forwarded-Host \$server_name;  
  }
}" >/etc/nginx/conf.d/CyberRange-$NAME-443.conf
  done
  
  Display -h "    Restarting NGinx on Master"
  service nginx stop
  service nginx start

  Display "Spreading Vigrid config to slaves..."
  /home/gns3/vigrid/bin/vigrid-spread -K /home/gns3/etc/id_GNS3 -U root -S /home/gns3/etc/vigrid.conf || Error 'Vigrid-spread error,'

  Display "Updating Vigrid on slaves..."
  /home/gns3/vigrid/bin/vigrid-run -S -K /home/gns3/etc/id_GNS3 -U root -A '/home/gns3/bin/vigrid-update'
  
  Display "Adding API on slaves..."
  /home/gns3/vigrid/bin/vigrid-run -S -K /home/gns3/etc/id_GNS3 -U root -A '/home/gns3/vigrid/install/vigrid2-add-api-to-slave.sh SLAVE'

  exit
fi

############## Part of script to run on Slave(s)

HOST=`hostname`
Display "Adding API to Slave $HOST..."

Display "Installing PHP FPM..." && apt install -y php-fpm || Error 'Install failed,'
apt install -y php-curl php-mail php-net-smtp || Error 'Install failed,'
Display "Removing Apache2 forced install..." && apt purge -y apache2* || Error 'Uninstall failed,'

Display -h "  Configuring PHP pools..."

PHP_VER=`php -v|head -1|awk '{print $2;}'| awk 'BEGIN { FS="."; } { print $1"."$2; }'`
Display -h "    PHP version is $PHP_VER."

Display -h "    Removing default PHP pools..."
rm /etc/php/$PHP_VER/fpm/pool.d/* || Error 'Cant remove pool,'

Display -h "    Adding Vigrid standard pool..."
echo "; Start a new pool named 'vigrid-www'.
; the variable $pool can be used in any directive and will be replaced by the
; pool name ('www' here)
[gns3-www]

; Unix user/group of processes
; Note: The user is mandatory. If the group is not set, the default user's group
;       will be used.
user = www-data
group = www-data

; The address on which to accept FastCGI requests.
; Valid syntaxes are:
;   'ip.add.re.ss:port'    - to listen on a TCP socket to a specific IPv4 address on
;                            a specific port;
;   '[ip:6:addr:ess]:port' - to listen on a TCP socket to a specific IPv6 address on
;                            a specific port;
;   'port'                 - to listen on a TCP socket to all addresses
;                            (IPv6 and IPv4-mapped) on a specific port;
;   '/path/to/unix/socket' - to listen on a unix socket.
; Note: This value is mandatory.
listen = /run/php/php$PHP_VER-fpm.sock

; Set permissions for unix socket, if one is used. In Linux, read/write
; permissions must be set in order to allow connections from a web server. Many
; BSD-derived systems allow connections regardless of permissions.
; Default Values: user and group are set as the running user
;                 mode is set to 0660
listen.owner = www-data
listen.group = www-data
;listen.mode = 0660

; Choose how the process manager will control the number of child processes.
; Possible Values:
;   static  - a fixed number (pm.max_children) of child processes;
;   dynamic - the number of child processes are set dynamically based on the
;             following directives. With this process management, there will be
;             always at least 1 children.
;             pm.max_children      - the maximum number of children that can
;                                    be alive at the same time.
;             pm.start_servers     - the number of children created on startup.
;             pm.min_spare_servers - the minimum number of children in 'idle'
;                                    state (waiting to process). If the number
;                                    of 'idle' processes is less than this
;                                    number then some children will be created.
;             pm.max_spare_servers - the maximum number of children in 'idle'
;                                    state (waiting to process). If the number
;                                    of 'idle' processes is greater than this
;                                    number then some children will be killed.
;  ondemand - no children are created at startup. Children will be forked when
;             new requests will connect. The following parameter are used:
;             pm.max_children           - the maximum number of children that
;                                         can be alive at the same time.
;             pm.process_idle_timeout   - The number of seconds after which
;                                         an idle process will be killed.
; Note: This value is mandatory.
pm = dynamic

; The number of child processes to be created when pm is set to 'static' and the
; maximum number of child processes when pm is set to 'dynamic' or 'ondemand'.
; This value sets the limit on the number of simultaneous requests that will be
; served. Equivalent to the ApacheMaxClients directive with mpm_prefork.
; Equivalent to the PHP_FCGI_CHILDREN environment variable in the original PHP
; CGI. The below defaults are based on a server without much resources. Don't
; forget to tweak pm.* to fit your needs.
; Note: Used when pm is set to 'static', 'dynamic' or 'ondemand'
; Note: This value is mandatory.
pm.max_children = 8

; The number of child processes created on startup.
; Note: Used only when pm is set to 'dynamic'
; Default Value: min_spare_servers + (max_spare_servers - min_spare_servers) / 2
pm.start_servers = 4

; The desired minimum number of idle server processes.
; Note: Used only when pm is set to 'dynamic'
; Note: Mandatory when pm is set to 'dynamic'
pm.min_spare_servers = 2

; The desired maximum number of idle server processes.
; Note: Used only when pm is set to 'dynamic'
; Note: Mandatory when pm is set to 'dynamic'
pm.max_spare_servers = 5

; Limits the extensions of the main script FPM will allow to parse. This can
; prevent configuration mistakes on the web server side. You should only limit
; FPM to .php extensions to prevent malicious users to use other extensions to
; execute php code.
; Note: set an empty value to allow all extensions.
; Default Value: .php
;security.limit_extensions = .php .php3 .php4 .php5 .php7
security.limit_extensions = .php .php3 .php4 .php5 .php7 .html .htm

; Extending default PHP script timeout
request_terminate_timeout = 300

; Default Value: nothing is defined by default except the values in php.ini and
;                specified at startup with the -d argument
;php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f www@my.domain.com
;php_flag[display_errors] = off
;php_admin_value[error_log] = /var/log/fpm-php.www.log
;php_admin_flag[log_errors] = on
;php_admin_value[memory_limit] = 32M" >/etc/php/$PHP_VER/fpm/pool.d/vigrid-www.conf

Display -h "Enabling & starting PHP-FPM..."
systemctl enable php$PHP_VER-fpm
service php$PHP_VER-fpm stop
service php$PHP_VER-fpm start

# NGinx for Vigrid extensions
Display -h "Installing NGinx server..."
Display -h "  Installing required packages..." && apt install -y curl bc gnupg2 ca-certificates lsb-release || Error 'Install failed,'

Display -h "  Updating apt sources for NGinx..."
echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list || Error 'Update failed,'
#echo "deb http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list || Error 'Update failed,'

Display -h "  Adding NGinx key..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - || Error 'Add failed,'
apt-key fingerprint ABF5BD827BD9BF62 || Error 'Fingerprint add failed,'

Display -h "  Updating system..." && apt update -y  || Error 'Update failed,'
Display -h "  Installing NGinx & extras..." && apt install -y nginx || Error 'Install failed,'

Display -h -n "  Checking NGinx version >=1.19..."
VER=`nginx -V 2>&1|head -1|sed 's/^.*nginx\///'| awk 'BEGIN { FS="."; } { print $1"."$2; }'`
if [ 1 -eq "$(echo "$VER >= 1.19" | bc)" ]
then
  Display -h "OK"
else
  Error "NGinx version ($VER) must be >=1.19."
fi

Display -h "  Configuring NGinx..."
rm -f /etc/nginx/conf.d/*

echo "#
# Vigrid HTTPS access for Vigrid-API
#
server {
  listen 443 ssl default;
  server_name localhost;

  # Take fullchain here, not cert.pem
  ssl_certificate      /etc/nginx/ssl/localhost.crt;
  ssl_certificate_key  /etc/nginx/ssl/localhost.key;

  ssl_session_cache    builtin:1000 shared:SSL:1m;
  ssl_session_timeout  5m;

  ssl_protocols   TLSv1.2 TLSv1.3;
  ssl_ciphers  HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers  on;

  # hide version
  server_tokens        off;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  root   /home/gns3/vigrid/www/site;

  # Vigrid home page
  location /
  {
    # sanity
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { log_not_found off; }

    location ~ \.css  { add_header Content-Type text/css; }
    location ~ \.js   { add_header Content-Type application/x-javascript; }
    location ~ \.eot  { add_header Content-Type application/vnd.ms-fontobject; }
    location ~ \.woff { add_header Content-Type font/woff; }

    location ~* \.(htm|html|php)\$
    {
      try_files                     \$uri =404;
      fastcgi_split_path_info       ^(.+\.html)(/.+)\$;
      fastcgi_index                 index.html;
      fastcgi_pass                  unix:/run/php/php$PHP_VER-fpm.sock;
      # Minimum output buffering
      fastcgi_buffers               2 4k;
      fastcgi_busy_buffers_size     4k;
      fastcgi_buffering             off;
      # fastcgi_buffer_size           8k; 
      include                       /etc/nginx/fastcgi_params;
      fastcgi_read_timeout          300;
      fastcgi_param PATH_INFO       \$fastcgi_path_info;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
  }

  location /manager
  {
    deny all;
    return 404;
  }

  # Vigrid API, load only
  location /vigrid-api
  { rewrite ^/vigrid-api/(.*)$ /vigrid-host-api.html?order=\$1 permanent; }

  location ~ ^/(images|javascript|js|css|flash|media|static|font)/  {
    expires 7d;
  }

  location ~ /\.ht {
      deny  all;
  }

  try_files \$uri \$uri/ /index.html?\$args /index.htm?\$args /index.php?\$args;
}
" >>/etc/nginx/conf.d/CyberRange-443-api.conf

echo "#
# Vigrid NGinx configuration file
#
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

user www-data;

events {
        worker_connections 2048;
}

http {

        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;

        server_tokens off;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;
  
        # Logging Settings
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        # Gzip Settings
        gzip on;

        # Appliance or whatever upload, applies to all
        client_max_body_size 8192M; # 8GB

        # Virtual Host Configs
        include /etc/nginx/conf.d/*.conf;
}
" >/etc/nginx/nginx.conf

Display -h "Adding www-data user to gns3 group..."
usermod -a www-data -G gns3 >/dev/null 2>/dev/null || Error 'add failed,'

Display -h "Generating SSL certificate for localhost..."
mkdir -p /etc/nginx/ssl >/dev/null 2>/dev/null
( printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth") | openssl req -x509 -out /etc/nginx/ssl/localhost.crt -keyout /etc/nginx/ssl/localhost.key -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' || Error 'Certificate generation failed,'

Display -h "Enabling & starting NGinx..."
systemctl enable nginx
service nginx stop
service nginx start

################################

# Adding Vigrid monitoring
Display "Installing & enabling Vigrid-load monitoring..."
cp /home/gns3/vigrid/etc/init.d/vigrid-load /etc/init.d/
systemctl enable --now vigrid-load

Display -h ""

) 2>&1 | tee -a $LOG_FILE
