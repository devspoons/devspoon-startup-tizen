#!/bin/bash

while :
do 
    echo "* if your webroot has sub-level, you should be insert as \\\/A\\\/B\\\/C"
    echo "ex) shop\\\/django_sample"
    echo -n "Enter the service web root without the path of '/www/' >"
    read webroot
    echo  "Entered service web root: $webroot"
    if [[ "$webroot" != "" ]]; then
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
    echo -n "Enter the app name >"
    read appname
    echo  "Entered app name: $appname"
    if [[ "$appname" != "" ]]; then
        break
    fi
done 

echo "Enter the serviceport"
echo -n "if you push enter with none, there are no port number >"
read serviceport
echo  "Entered proxy port: $serviceport"

while :
do 
    echo -n "Enter the file name >"
    read filename
    echo  "Entered file name: $filename"
    if [[ "$filename" != "" ]]; then
        break
    fi
done 

sed 's/webroot/'$webroot'/g' sample_nginx.conf > $filename'1'.temp
sed 's/portnumber/'$portnumber'/g' $filename'1'.temp > $filename'2'.temp
sed 's/domain/'$domain'/g' $filename'2'.temp > $filename'3'.temp
sed 's/appname/'$appname'/g' $filename'3'.temp > $filename'4'.temp
if [[ "$serviceport" == "" ]]; then
    sed 's/:serviceport/''/g' $filename'4'.temp > $filename'5'.temp
else
    sed 's/serviceport/'$serviceport'/g' $filename'4'.temp > $filename'5'.temp
fi
sed 's/filename/'$filename'/g' $filename'5'.temp > ./conf.d/$filename'_gunicorn_ng'.conf 

rm *.temp
