#!/bin/bash

mkdir /root/RPi4_boot_img
cd /root/RPi4_boot_img
git clone ssh://review.tizen.org/platform/kernel/linux-rpi
cd /root/RPi4_boot_img/linux-rpi
git checkout -b tizen-port 4453fe27ce2bb0db993870729a17919a35c74de
cd /root/RPi4_boot_img
cp /root/build-script/.gbs.conf ./
time gbs build -A armv7l --buildroot=~/GBS-RPI4-ROOT/tizen_rpi4 --include-all --thread=4 --clean
cp /root/build-script/tizen-unified_20201020.1_iot-boot-armv7l-rpi4.ks ./
time mic cr loop tizen-unified_20201020.1_iot-boot-armv7l-rpi4.ks --pack-to=tizen-unified_20201020.1_iot-boot-armv7l-rpi4.tar.gz --logfile=mic_build.log -A armv7l