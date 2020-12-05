#!/bin/bash

mkdir ~/tizen_src && cd ~/tizen_src

repo init -u tizen:scm/manifest -b tizen -m unified_standard.xml

wget http://download.tizen.org/releases/weekly/tizen/unified/tizen-unified_20190807.5/builddata/manifest/tizen-unified_20190807.5_standard_preloadapp.xml -O .repo/manifests/unified/standard/projects.xml

sed -i '3,4d' .repo/manifests/unified/standard/projects.xml

repo sync -j 16

cp /root/tizen_project/repo-script/.gbs.conf /root/tizen_src
