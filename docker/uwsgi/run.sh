#!/bin/bash

requirements_file="requirements.txt"

if [ -f $requirements_file ]; then
        echo $requirements_file "is exists."
        pip install -r requirements.txt
fi

uwsgi --ini /application/uwsgi.ini

while true; 
do 
    echo "still live"; 
    sleep 600; 
done
