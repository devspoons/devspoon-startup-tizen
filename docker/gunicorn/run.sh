#!/bin/bash

cd /www/django_sample

requirements_file="requirements.txt"

if [ -f $requirements_file ]; then
        echo $requirements_file "is exists."
        pip install -r requirements.txt
fi

gunicorn --workers 4 --bind 0.0.0.0:8000 django_sample.wsgi:application --daemon --reload

while true; 
do 
    echo "still live"; 
    sleep 600; 
done
