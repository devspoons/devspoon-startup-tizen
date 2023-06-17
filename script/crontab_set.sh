#!/bin/bash

crontab -l | { cat; echo "0 6 * * 1 docker restart nginx-gunicorn-webserver"; } | crontab -