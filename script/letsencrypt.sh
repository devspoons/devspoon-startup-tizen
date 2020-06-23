#!/bin/bash

apt-get update  &&  apt-get install -y sendmail wget vim cron ca-certificates

wget --no-check-certificate https://dl.eff.org/certbot-auto \
 && mv certbot-auto /usr/local/bin/certbot-auto \
 && chown root /usr/local/bin/certbot-auto \
 && chmod 0755 /usr/local/bin/certbot-auto \
 && certbot-auto --version -n

while :
do 
    echo -n "Enter the service webroot_folder >"
    read webroot_folder
    echo  "Entered service webroot_folder: $webroot_folder"
    if [[ "$webroot_folder" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter the service domain >"
    read domain
    echo  "Entered service domain: $domain"
    if [[ "$domain" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter the user e-mail >"
    read mail
    echo  "Entered user e-mail: $mail"
    if [[ "$mail" != "" ]]; then
        break
    fi
done 

#if ! test -d /etc/letsencrypt/live/test.com ; 
if ! test -d /ssl/letsencrypt/live/domain ; then 
    echo "try to get authentication key using certbot-auto "
    certbot-auto -n certonly -n --webroot -w /www/webroot_folder/ -d domain --agree-tos -m mail; 
    cp /etc/letsencrypt/ /ssl/letsencrypt/ -rf 
else
    echo "copy letsencrypt folder by already maden"
    cp /ssl/letsencrypt/ /etc/letsencrypt/ -rf
fi

#if ! test -f /etc/ssl/certs/dhparam.pem ; 
if test -f /ssl/ssl/certs/dhparam.pem ; then 
    echo "try to get ssl key using openssl "
    openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096; 
    cp /etc/ssl/certs/dhparam.pem /ssl/certs/dhparam.pem -rf
else
    echo "copy ssl folder by already maden"
    cp /ssl/certs/dhparam.pem /etc/ssl/certs/dhparam.pem -rf
fi

cat <(crontab -l) <(echo "0 5 * * 1 certbot-auto renew --quiet --renew-hook "/etc/init.d/nginx reload"") | crontab -
