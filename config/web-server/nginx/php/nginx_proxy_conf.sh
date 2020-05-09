#!/bin/bash

account=$1
domain=$2
portnumber=$3
realurl='http:\/\/'$4':'$5

sed 's/realurl;/'$realurl';/' sample_nginx_proxy.conf > $account'1'.temp
sed 's/portnumber;/'$portnumber';/' $account'1'.temp > $account'2'.temp
sed 's/domain/'$domain'/g' $account'2'.temp > ./sites-available/$account'_proxy_ng'.conf 

rm *.temp
