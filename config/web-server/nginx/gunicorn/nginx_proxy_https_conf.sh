#!/bin/bash

while :
do 
    echo -n "Enter the account >"
    read account
    echo  "Entered account: $account"
    if [[ "$account" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter the domain >"
    read domain
    echo  "Entered domain: $domain"
    if [[ "$domain" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter the portnumber >"
    read portnumber
    echo  "Entered portnumber: $portnumber"
    if [[ "$portnumber" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter the proxyurl >"
    read proxyurl
    echo  "Entered proxyurl: $proxyurl"
    if [[ "$proxyurl" != "" ]]; then
        break
    fi
done 


echo -n "Enter the proxyport >"
read proxyport
echo  "Entered proxyport: $proxyport"


sed 's/realurl;/'$realurl';/' sample_nginx_proxy_https.conf > $account'1'.temp
sed 's/portnumber;/'$portnumber';/' $account'1'.temp > $account'2'.temp
sed 's/proxyurl/'$proxyurl'/' $account'2'.temp > $account'3'.temp
if [[ "$proxyport" == "" ]]; then
    sed 's/:proxyport/''/g' $account'3'.temp > ./pool.d/$account'_proxy_https_ng'.conf
else
    sed 's/proxyport/'$proxyport'/g' $account'3'.temp > ./pool.d/$account'_proxy_https_ng'.conf
fi

rm *.temp
