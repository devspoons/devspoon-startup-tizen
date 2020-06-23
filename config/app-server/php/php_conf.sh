#!/bin/bash

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
    echo -n "Enter the service portnumber >"
    read portnumber
    echo  "Entered service portnumber: $portnumber"
    if [[ "$portnumber" != "" ]]; then
        break
    fi
done 

sed 's/domain/'$domain'/' sample_php.conf > $domain'1'.temp
sed 's/portnumber/'$portnumber'/' $domain'1'.temp > ./pool.d/$domain'_php'.conf

rm *.temp