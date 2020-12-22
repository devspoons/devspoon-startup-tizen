#!/bin/sh

set -e

echo 'step 1. prefare'

echo "Set a workspace for building up boot image"
if [ ! -d /rootRPi4_boot_img ]; then
    mkdir /root/RPi4_boot_img
fi

echo "Download a git repository"

echo "git clone the package of linux-rpi"
cd /root/RPi4_boot_img
git clone ssh://review.tizen.org/platform/kernel/linux-rpi

echo "git checkout the package of linux-rpi"
cd /root/RPi4_boot_img/linux-rpi
git checkout -b tizen-port 4453fe27ce2bb0db993870729a17919a35c74de


echo 'step 2. build up'

echo "gbs building up refering the .gbs.conf file"
cd /root/RPi4_boot_img
cp /root/build-script/.gbs.conf ./
time gbs build -A armv7l --buildroot=/root/GBS-RPI4-ROOT/tizen_rpi4 --include-all --thread=4 --clean

echo 'step 3. make a image'

echo "mic building up refering the ks file to make a tizen image" 
cp /root/build-script/tizen-unified_iot-boot-armv7l-rpi4.ks ./
time mic cr loop tizen-unified_iot-boot-armv7l-rpi4.ks --pack-to=tizen-unified_iot-boot-armv7l-rpi4.tar.gz --logfile=mic_build.log -A armv7l
