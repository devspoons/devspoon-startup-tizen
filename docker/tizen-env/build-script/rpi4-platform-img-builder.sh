#!/bin/bash

mkdir /root/RPi4_platform_img
cd /root/PRi4_platform_img
cp /root/build-script/tizen-unified_20200521.1_iot-headed-3parts-armv7l-rpi3.ks ./
time mic cr loop tizen-unified_20200521.1_iot-headed-3parts-armv7l-rpi3.ks --pack-to=tizen-unified_20200521.1_iot-headed-3parts-armv7l-rpi3.tar.gz --logfile=mic_build.log -A armv7l