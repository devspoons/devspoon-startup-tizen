#!/bin/bash

account=$1
domain=$2
portnumber=$3
appname=$4
service_port=$5

sed 's/account/'$account'/' sample_nginx_https.conf > $account'1'.temp
sed 's/domain/'$domain'/g' $account'1'.temp > $account'2'.temp
sed 's/portnumber;/'$portnumber';/' $account'2'.temp > $account'3'.temp
sed 's/appname;/'$appname';/' $account'3'.temp > $account'4'.temp
sed 's/service_port/'$service_port'/' $account'4'.temp > ./sites-available/$account'_https_ng'.conf 

rm *.temp
