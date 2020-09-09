#!/bin/bash

cd /www/py37/django_test/repo

requirements_file="requirements.txt"

if [ -f $requirements_file ]; then
        echo $requirements_file "is exists."
        pip install -r requirements.txt
fi

gunicorn --workers 4 --bind 0.0.0.0:8000 conf.wsgi:application --daemon --reload

while true; 
do 
    echo "still live"; 
    sleep 600; 
done
