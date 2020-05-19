#!/bin/bash

uwsgi --ini /application/uwsgi.ini

while true; 
do 
    echo "still live"; 
    sleep 600; 
done
