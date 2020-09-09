#!/bin/bash

while :
do 
    echo -n "Enter the service portnumber >"
    echo -n "* if your webroot has sub-level, you should be insert as \\\/A\\\/B\\\/C"
    read portnumber
    echo  "Entered service portnumber: $portnumber"
    if [[ "$portnumber" != "" ]]; then
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
    echo -n "Enter the proxy url >"
    read proxyurl
    echo  "Entered proxy url: $proxyurl"
    if [[ "$proxyurl" != "" ]]; then
        break
    fi
done 

echo "Enter the proxy port"
echo -n "if you push enter with none, there are no port number >"
read proxyport
echo  "Entered proxy port: $proxyport"

while :
do 
    echo -n "Enter the file name >"
    read filename
    echo  "Entered file name: $filename"
    if [[ "$filename" != "" ]]; then
        break
    fi
done 

sed 's/portnumber/'$portnumber'/g' sample_nginx_proxy_https.conf > $filename'1'.temp
sed 's/domain/'$domain'/g' $filename'1'.temp > $filename'2'.temp
sed 's/proxyurl/'$proxyurl'/g' $filename'2'.temp > $filename'3'.temp
if [[ "$proxyport" == "" ]]; then
    sed 's/:proxyport/''/g' $filename'3'.temp > $filename'4'.temp
else
    sed 's/proxyport/'$proxyport'/g' $filename'3'.temp > $filename'4'.temp
fi
sed 's/filename/'$filename'/g' $filename'4'.temp > ./conf.d/$filename'_proxy_https_ng'.conf

rm *.temp