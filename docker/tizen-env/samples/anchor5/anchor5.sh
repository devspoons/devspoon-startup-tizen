#!/bin/bash

mkdir ~/Tizen-Work

cp gbsAnchor5.conf ~/Tizen-Work
cp tizen-unified_iot-headed-3parts-armv7l-artik530.ks ~/Tizen-Work 

cd ~/Tizen-Work

git clone ssh://review.tizen.org/platform/core/api/peripheral-io
cd peripheral-io
git checkout -b tizen-port 70dcc13c092288d06b6bb6255756f26ffd07b0fb

cd ~/Tizen-Work

gbs -c ./gbsAnchor5.conf build -A armv7l --thread=4

mic cr loop tizen-unified_iot-headed-3parts-armv7l-artik530.ks --pack-to=tizen-unified_iot-headed-3parts-armv7l-artik530.tar.gz --logfile=mic_build.log -A armv7l
