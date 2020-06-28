#!/bin/bash

bash /usr/sbin/sshd -D

while true; 
do 
    echo "still live"; 
    sleep 600; 
done
