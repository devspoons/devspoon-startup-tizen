#!/bin/bash

account=$1
domain=$2
portnumber=$3
phpport=$4

sed 's/account/'$account'/' sample_nginx.conf > $account'1'.temp
sed 's/domain/'$domain'/g' $account'1'.temp > $account'2'.temp
sed 's/portnumber;/'$portnumber';/' $account'2'.temp > $account'3'.temp
sed 's/phpport/'$phpport'/' $account'3'.temp > ./sites-available/$account'_ng'.conf

rm *.temp
