#!/bin/bash

apt-get update  &&  apt-get install -y sendmail wget vim cron

wget https://dl.eff.org/certbot-auto \
    && mv certbot-auto /usr/local/bin/certbot-auto \
    && chown root /usr/local/bin/certbot-auto \
    && chmod 0755 /usr/local/bin/certbot-auto \
    && certbot-auto --version -n

if ! test -d /etc/letsencrypt/live/<domain>; then certbot-auto -n certonly -n --webroot -w /www/<web root folder>/ -d <domain> --agree-tos -m <mail address>; fi

if ! test -f /etc/ssl/certs/dhparam.pem; then openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096; fi

cat <(crontab -l) <(echo "0 5 * * 1 certbot-auto renew --quiet --renew-hook "/etc/init.d/nginx reload"") | crontab -
