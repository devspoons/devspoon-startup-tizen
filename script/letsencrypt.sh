#!/bin/bash

my_array=()
delimiter="-d"
domain_string=""

apt-get update  &&  apt-get install -y sendmail wget vim cron certbot python3-certbot-nginx ca-certificates
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
    echo -n "To add a subdomain, type something like 'aaa.com www.aaa.com sub.aaa.com', but all domains refer to the same web root"
    echo -n "A domain in aaa.com format must be entered first."
    echo -n "Enter the service domain >"
    read domain
    echo  "Entered service domain: $domain"
    if [[ "$domain" != "" ]]; then
        break
    fi
done 

IFS=' ' read -ra my_array <<< "$domain"

while :
do 
    echo -n "Enter the user e-mail >"
    read mail
    echo  "Entered user e-mail: $mail"
    if [[ "$mail" != "" ]]; then
        break
    fi
done 

for element in "${my_array[@]}"; do
    domain_string+=" $delimiter $element"
done

# Remove leading space
# domain_string="${domain_string# }"

# for element in "${my_array[@]}"; do
#if ! test -f /etc/ssl/certs/dhparam.pem ; 
if ! test -f /etc/ssl/certs/${my_array[0]}/dhparam.pem ; then 
    echo "try to create ssl key using openssl "
    if ! test -d /etc/ssl/certs/${my_array[0]}/ ; then
        echo "create domain folder: /etc/ssl/certs/"${my_array[0]}"/"
        mkdir -p /etc/ssl/certs/${my_array[0]}/
    fi
    openssl dhparam -out /etc/ssl/certs/${my_array[0]}/dhparam.pem 4096
    # if ! test -d /ssl/certs/$domain/ ; then
    #     echo "create domain folder: /ssl/certs/"$domain"/"
    #     mkdir -p /ssl/certs/$domain/
    # fi
    # cp /etc/ssl/certs/dhparam.pem /ssl/certs/$domain/ -r
# else
#     echo "copy ssl folder by already maden"
#     cp /ssl/certs/$domain/dhparam.pem /etc/ssl/certs/dhparam.pem -r
fi
# done

#if ! test -d /etc/letsencrypt/live/test.com ; 
if ! test -d /etc/ssl/letsencrypt/$domain/letsencrypt ; then 
    echo "try to create authentication key using certbot "
    certbot certonly --agree-tos --email $mail --webroot -w $webroot_folder $domain
    echo "certbot certonly --agree-tos --email "$mail" --webroot -w "$webroot_folder$domain_string
    # if ! test -d /ssl/letsencrypt/$domain/ ; then
    #     echo "create domain folder: /ssl/letsencrypt/"$domain"/"
    #     mkdir -p /ssl/letsencrypt/$domain/
    # fi
    #cp /etc/letsencrypt/ /ssl/letsencrypt/$domain/ -r
# else
#     echo "copy letsencrypt folder by already maden"
#     cp /ssl/letsencrypt/$domain/ /etc/letsencrypt/ -r
fi

# cat <(crontab -l) <(echo "0 5 * * 1 certbot renew --quiet --renew-hook \"service nginx reload\"") | crontab -