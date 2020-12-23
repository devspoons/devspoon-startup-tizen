#!/bin/sh

set -e

echo 'step 1. prefare'

echo "Set a workspace for building up platform img"
if [ ! -d /root/RPi4_platform_img ]; then
    mkdir /root/RPi4_platform_img
fi

echo "Download a git repository"

echo "git clone the package of peripheral-io"
cd /root/RPi4_platform_img
rm peripheral-io -rf
git clone ssh://review.tizen.org/platform/core/api/peripheral-io

echo "git checkout the package of peripheral-io"
cd /root/RPi4_platform_img/peripheral-io
git checkout -b tizen-port 750fa17c1d5f79a613b2d0ce90234ff4444f1f50

echo 'step 2. build up'

echo "gbs building up refering the .gbs.conf file"
cd /root/RPi4_platform_img
cp /root/build-script/.gbs.conf ./
gbs build -A armv7l --buildroot=/root/GBS-RPI4-ROOT/tizen_rpi4 --include-all --thread=1 --clean

echo 'step 3. make a image'

echo "mic building up refering the ks file to make a tizen image" 
cp /root/build-script/tizen-unified_iot-headed-3parts-armv7l-rpi4.ks ./
mic cr loop tizen-unified_iot-headed-3parts-armv7l-rpi4.ks --pack-to=tizen-unified_iot-headed-3parts-armv7l-rpi4.tar.gz --logfile=mic_build.log -A armv7l
