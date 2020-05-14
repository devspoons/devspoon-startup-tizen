#!/bin/bash

cd /www/py37/django_test/repo

gunicorn --workers 4 --bind 0.0.0.0:8000 conf.wsgi:application --daemon --reload

while true; 
do 
    echo "still live"; 
    sleep 600; 
done
