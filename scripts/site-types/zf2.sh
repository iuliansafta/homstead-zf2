#!/usr/bin/env bash
# Script for setting up the web server for any of the following applications:
#
# - Apigility
# - Expressive
# - zend-mvc
#
# Type declaration in Homestead.yaml should be one of:
#
# - apigility
# - expressive
# - zf
# - zf2
#
# The first two are aliases for the last.

declare -A params=$6       # Create an associative array
declare -A headers=${9}    # Create an associative array
declare -A rewrites=${10}  # Create an associative array
paramsTXT=""
if [ -n "$6" ]; then
    for element in "${!params[@]}"
    do
        paramsTXT="${paramsTXT}
        fastcgi_param ${element} ${params[$element]};"
    done
fi
headersTXT=""
if [ -n "${9}" ]; then
   for element in "${!headers[@]}"
   do
      headersTXT="${headersTXT}
      add_header ${element} ${headers[$element]};"
   done
fi
rewritesTXT=""
if [ -n "${10}" ]; then
   for element in "${!rewrites[@]}"
   do
      rewritesTXT="${rewritesTXT}
      location ~ ${element} { if (!-f \$request_filename) { return 301 ${rewrites[$element]}; } }"
   done
fi

if [ "$7" = "true" ]
then configureXhgui="
location /xhgui {
        try_files \$uri \$uri/ /xhgui/index.php?\$args;
}
"
else configureXhgui=""
fi

block="server {
    listen ${3:-80};
    listen ${4:-443} ssl http2;
    server_name $1;
    root \"$2\";

    index index.html index.htm index.php dispatcher.php;

    charset utf-8;

    # CORS support
    more_set_headers 'Access-Control-Allow-Origin: \$http_origin';
    more_set_headers 'Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE, HEAD';
    more_set_headers 'Access-Control-Allow-Credentials: true';
    more_set_headers 'Access-Control-Allow-Headers: Origin,Content-Type,Accept,Authorization,Authentication-Method-Id';  
    
    $rewritesTXT

    location / {
        if (\$request_method = 'OPTIONS') {
            more_set_headers 'Access-Control-Allow-Origin: \$http_origin';
            more_set_headers 'Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE, HEAD';
            more_set_headers 'Access-Control-Max-Age: 1728000';
            more_set_headers 'Access-Control-Allow-Credentials: true';
            more_set_headers 'Access-Control-Allow-Headers: Origin,Content-Type,Accept,Authorization';
            more_set_headers 'Content-Type: text/plain; charset=UTF-8';
            more_set_headers 'Content-Length: 0';
            return 204;
        }

        try_files \$uri \$uri/ /dispatcher.php?\$query_string;
        $headersTXT
    }

    location /img/categories {
        alias /home/www/clikd-api/public/categories;
    }

    location /img/photos {
        alias /home/www/clikd-api/public/photos;
    }

    location /img/users {
        alias /home/www/clikd-api/public/users;
    }

    location /img/test-results {
        alias /home/www/clikd-api/public/test-results;
    }

    location /downloads {
        alias /home/www/clikd-api/public/downloads;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/$1-ssl-error.log error;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        fastcgi_pass unix:/var/run/php/php$5-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root/\$fastcgi_script_name;
        $paramsTXT

        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.ht {
        deny all;
    }

    $configureXhgui

    ssl_session_cache shared:SSL:10m;
    ssl_certificate     /etc/nginx/ssl/$1.crt;
    ssl_certificate_key /etc/nginx/ssl/$1.key;
}
"

echo "$block" > "/etc/nginx/sites-available/$1"
ln -fs "/etc/nginx/sites-available/$1" "/etc/nginx/sites-enabled/$1"
