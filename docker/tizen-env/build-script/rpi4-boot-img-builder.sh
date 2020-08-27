#!/bin/bash

mkdir /root/RPi4_boot_img
cd /root/RPi4_boot_img
cp /root/build-script/tizen-unified_20200521.1_iot-boot-armv7l-rpi4.ks ./
time mic cr loop tizen-unified_20200521.1_iot-boot-armv7l-rpi4.ks --pack-to=tizen-unified_20200521.1_iot-boot-armv7l-rpi4.tar.gz --logfile=mic_build.log -A armv7l