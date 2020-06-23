#!/bin/bash

while :
do 
    echo -n "Enter the domain >"
    read domainname
    echo  "Entered domain: $domainname"
    if [[ "$domainname" != "" ]]; then
        break
    fi
done 

echo "if you don't input anything, it'll be default value"
echo -n "Enter the http port number [default : 80] >"
read httpport
if [[ "$httpport" == "" ]]; then
    httpport=80
fi
echo  "Entered http port number: $httpport"

while :
do 
    echo -n "do you want to set https now? (y/n) >"
    read yesno
    echo  "Entered setting mode: $yesno"

    if [[ "$yesno" == "y" ]]; then

        sed 's/##/''/' sample-harbor.yml > sharbor.yml

        echo "if you don't input anything, it'll be default value"
        echo -n "Enter the https port number [default : 443] >"
        read httpsport        
        if [[ "$httpsport" == "" ]]; then
            httpsport=443
        fi
        echo  "Entered https port number: $httpsport"        
        
        echo "if you don't input anything, it'll be default value"
        echo "example : \/tmp\/local\/ssl"
        echo -n "Enter the ssl path [default : \/etc] >"
        read sslpath
        if [[ "$sslpath" == "" ]]; then
            sslpath="\/etc"
        fi
        echo  "Entered the ssl path: $sslpath"
        break
    
    elif [[ "$yesno" == "n" ]]; then
        echo "you don't use https in this harbor"        
        httpsport=443
        sslpath="\/tmp"
        cp sample-harbor.yml  sharbor.yml
        break
    fi

done

while :
do 
    echo -n "Enter the harbor admin password >"
    read harboradminpassword
    echo  "Entered harbor admin password: $harboradminpassword"
    if [[ "$harboradminpassword" != "" ]]; then
        break
    fi    
done 

while :
do 
    echo -n "Enter the database password >"
    read databasepassword
    echo  "Entered database password: $databasepassword"
    if [[ "$databasepassword" != "" ]]; then
        break
    fi    
done 

echo "if you don't input anything, it'll be default value"
echo "example : \/tmp\/local\/lang"
echo -n "Enter the data volume path (full path) [default : \/data] >"
read datavolume
if [[ "$datavolume" == "" ]]; then
    datavolume="\/data"
fi
echo  "Entered data volume path: $datavolume"

echo "if you don't input anything, it'll be default value"
echo "example : \/tmp\/local\/lang"
echo -n "Enter the log path  [default : \/var\/log\/harbor] >"
read logpath
if [[ "$logpath" == "" ]]; then
    logpath="\/var\/log\/harbor"
fi
echo  "Entered log path: $logpath"

sed 's/domain-name/'$domainname'/g' sharbor.yml > sample-harbor'1'.temp
sed 's/http-port/'$httpport'/g' sample-harbor'1'.temp > sample-harbor'2'.temp
sed 's/https-port/'$httpsport'/g' sample-harbor'2'.temp > sample-harbor'3'.temp
sed 's/ssl-path/'$sslpath'/g' sample-harbor'3'.temp > sample-harbor'4'.temp
sed 's/harbor-admin-password/'$harboradminpassword'/g' sample-harbor'4'.temp > sample-harbor'5'.temp
sed 's/database-password/'$databasepassword'/g' sample-harbor'5'.temp > sample-harbor'6'.temp
sed 's/data-volume/'$datavolume'/g' sample-harbor'6'.temp > sample-harbor'7'.temp
sed 's/log-path/'$logpath'/g' sample-harbor'7'.temp > harbor.yml

rm *.temp sharbor.yml