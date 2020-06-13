#!/bin/bash

apt-get update  &&  apt-get install -y sendmail wget vim cron

wget --no-check-certificate https://dl.eff.org/certbot-auto \
 && mv certbot-auto /usr/local/bin/certbot-auto \
 && chown root /usr/local/bin/certbot-auto \
 && chmod 0755 /usr/local/bin/certbot-auto \
 && certbot-auto --version -n

#if ! test -d /etc/letsencrypt/live/cococok.com ; 
if ! test -d /ssl/letsencrypt/live/cococok.com ; then 
    echo "try to get authentication key using certbot-auto "
    certbot-auto -n certonly -n --webroot -w /www/cococok/ -d cococok.com --agree-tos -m bluebamus@naver.com; 
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
