#!/bin/bash

mkdir ~/tizen_rpi3 && cp .gbs.conf ~/tizen_rpi3/ && cp tizen-unified_20191031.1_iot-headed-3parts-armv7l-rpi3.ks ~/tizen_rpi3/
cd ~/tizen_rpi3

git clone ssh://review.tizen.org/platform/core/api/peripheral-io

cd peripheral-io

git checkout -b tizen-port 70dcc13c092288d06b6bb6255756f26ffd07b0fb

cd ~/tizen_rpi3

gbs build -A armv7l --thread=4 --clean 

mic cr loop tizen-unified_20191031.1_iot-headed-3parts-armv7l-rpi3.ks --pack-to=iot-boot-armv7l-rpi3.tar.gz --logfile=mic_build.log -A armv7l
