#!/bin/bash

while true
do
    sleep 5
    result=$(ps -ax|grep -v grep|grep systemd-journald)
    if [ "${#result}" -ne 0 ]
    then
        sleep 1
        echo 'systemctl daemon-reload'
        sleep 1
        echo 'systemctl start gunicorn'
        sleep 1
        echo 'systemctl enable gunicorn'
        break
    else
        echo "${#result}"
    fi
done
