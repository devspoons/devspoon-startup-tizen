#!/bin/bash
# 입력값은 일반 경로 그대로 입력한다(예: /tmp/local/ssl). 예전 안내의 "\/" 이스케이프 입력도 호환된다.
# sed 치환 전에 / & \ 를 이스케이프한다 — 이스케이프 없이 넣으면 경로·비밀번호가 sed 식을 깨 harbor.yml 이 망가진다.
unesc() { printf '%s' "${1//\\\//\/}"; }
sed_esc() { printf '%s' "$1" | sed -e 's/[\/&\\]/\\&/g'; }

while :
do 
    echo -n "Enter the domain >"
    read -r domainname
    echo  "Entered domain: $domainname"
    if [[ "$domainname" != "" ]]; then
        break
    fi
done 

echo "if you don't input anything, it'll be default value"
echo -n "Enter the http port number [default : 80] >"
read -r httpport
if [[ "$httpport" == "" ]]; then
    httpport=80
fi
echo  "Entered http port number: $httpport"

while :
do 
    echo -n "do you want to set https now? (y/n) >"
    read -r yesno
    echo  "Entered setting mode: $yesno"

    if [[ "$yesno" == "y" ]]; then

        sed 's/##/''/' sample-harbor.yml > sharbor.yml

        echo "if you don't input anything, it'll be default value"
        echo -n "Enter the https port number [default : 443] >"
        read -r httpsport
        if [[ "$httpsport" == "" ]]; then
            httpsport=443
        fi
        echo  "Entered https port number: $httpsport"        
        
        echo "if you don't input anything, it'll be default value"
        echo "example : /tmp/local/ssl"
        echo -n "Enter the ssl path [default : /etc] >"
        read -r sslpath
        if [[ "$sslpath" == "" ]]; then
            sslpath="/etc"
        fi
        echo  "Entered the ssl path: $sslpath"
        break
    
    elif [[ "$yesno" == "n" ]]; then
        echo "you don't use https in this harbor"        
        httpsport=443
        sslpath="/tmp"
        cp sample-harbor.yml  sharbor.yml
        break
    fi

done

while :
do 
    echo -n "Enter the harbor admin password >"
    read -r harboradminpassword
    echo  "Entered harbor admin password: $harboradminpassword"
    if [[ "$harboradminpassword" != "" ]]; then
        break
    fi    
done 

while :
do 
    echo -n "Enter the database password >"
    read -r databasepassword
    echo  "Entered database password: $databasepassword"
    if [[ "$databasepassword" != "" ]]; then
        break
    fi    
done 

echo "if you don't input anything, it'll be default value"
echo "example : /tmp/local/data"
echo -n "Enter the data volume path (full path) [default : /data] >"
read -r datavolume
if [[ "$datavolume" == "" ]]; then
    datavolume="/data"
fi
echo  "Entered data volume path: $datavolume"

echo "if you don't input anything, it'll be default value"
echo "example : /tmp/local/log"
echo -n "Enter the log path  [default : /var/log/harbor] >"
read -r logpath
if [[ "$logpath" == "" ]]; then
    logpath="/var/log/harbor"
fi
echo  "Entered log path: $logpath"

sslpath=$(unesc "$sslpath"); datavolume=$(unesc "$datavolume"); logpath=$(unesc "$logpath")
sed "s/domain-name/$(sed_esc "$domainname")/g" sharbor.yml > sample-harbor'1'.temp
sed "s/http-port/$(sed_esc "$httpport")/g" sample-harbor'1'.temp > sample-harbor'2'.temp
sed "s/https-port/$(sed_esc "$httpsport")/g" sample-harbor'2'.temp > sample-harbor'3'.temp
sed "s/ssl-path/$(sed_esc "$sslpath")/g" sample-harbor'3'.temp > sample-harbor'4'.temp
sed "s/harbor-admin-password/$(sed_esc "$harboradminpassword")/g" sample-harbor'4'.temp > sample-harbor'5'.temp
sed "s/database-password/$(sed_esc "$databasepassword")/g" sample-harbor'5'.temp > sample-harbor'6'.temp
sed "s/data-volume/$(sed_esc "$datavolume")/g" sample-harbor'6'.temp > sample-harbor'7'.temp
sed "s/log-path/$(sed_esc "$logpath")/g" sample-harbor'7'.temp > harbor.yml

rm *.temp sharbor.yml