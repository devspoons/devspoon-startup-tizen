#!/bin/bash

echo -n "Enter a host name (default : gitolite) >"
read host_name
echo  "Entered a host name: $host_name"
if [[ "$host_name" != "" ]]; then
    host_name="gitolite"
fi


echo -n "Enter a User name (default : gitolite-creator) >"
read user_name
echo  "Entered a User name: $user_name"
if [[ "$user_name" != "" ]]; then
    user_name="gitolite-creator"
fi


while :
do 
    echo -n "Enter a domain >"
    read domain
    echo  "Entered a domain: $domain"
    if [[ "$domain" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter a port number >"
    read portnumber
    echo  "Entered a port number: $portnumber"
    if [[ "$portnumber" != "" ]]; then
        break
    fi
done 

while :
do  
    echo -n "Enter a IdentityFile path (default : ~/.ssh/git-manager) >"
    read identityFile_path
    echo  "Entered a IdentityFile path: $identityFile_path"
    if [[ "$identityFile_path" != "" ]]; then
        identityFile_path="~/.ssh/git-manager"
    fi
done 

sed 's/domain/'$domain'/' sample_config > sample_config'1'.temp
sed 's/portnumber/'$portnumber'/' sample_config'1'.temp > config

rm *.temp