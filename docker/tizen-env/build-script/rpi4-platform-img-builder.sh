#!/bin/bash

mkdir /root/RPi4_platform_img
cd /root/PRi4_platform_img
git clone ssh://review.tizen.org/platform/core/api/peripheral-io
cd /root/PRi4_platform_img/peripheral-io
git checkout -b tizen-port 750fa17c1d5f79a613b2d0ce90234ff4444f1f50
cd /root/PRi4_platform_img
cp /root/build-script/.gbs.conf
time gbs build -A armv7l --buildroot=/root/GBS-RPI4-ROOT/tizen_rpi4 --include-all --thread=4 --clean
cp /root/build-script/tizen-unified_20201020.1_iot-headed-3parts-armv7l-rpi4.ks ./
time mic cr loop tizen-unified_20201020.1_iot-headed-3parts-armv7l-rpi4.ks --pack-to=tizen-unified_20201020.1_iot-headed-3parts-armv7l-rpi4.tar.gz --logfile=mic_build.log -A armv7l