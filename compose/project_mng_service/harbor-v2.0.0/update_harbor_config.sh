#!/bin/bash

domainname = $1
httpport = $2
httpsport = $3
sslpath = $4
harboradminpassword = $5
databasepassword = $6
datavolume = $7
logpath = $8

sed 's/domain-name/'$domainname'/' sample-harbor.yml > sample-harbor'1'.temp
sed 's/http-port/'$httpport'/g' sample-harbor'1'.temp > sample-harbor'2'.temp
sed 's/https-port/'$httpsport'/g' sample-harbor'2'.temp > sample-harbor'3'.temp
sed 's/ssl-path/'$sslpath'/g' sample-harbor'3'.temp > sample-harbor'4'.temp
sed 's/harbor-admin-password/'$harboradminpassword'/g' sample-harbor'4'.temp > sample-harbor'5'.temp
sed 's/database-password/'$databasepassword'/g' sample-harbor'5'.temp > sample-harbor'6'.temp
sed 's/data-volume /'$datavolume'/g' sample-harbor'6'.temp > sample-harbor'7'.temp
sed 's/log-path/'$logpath'/' sample-harbor'7'.temp > harbor.yml

rm *.temp