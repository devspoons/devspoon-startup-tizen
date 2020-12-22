#!/bin/bash

set -e

echo 'step 1. repo init'

mkdir ~/tizen_src && cd ~/tizen_src

repo init -u tizen:scm/manifest -b tizen -m unified_standard.xml

echo "step 2. a unified xml file download of repo's manifests"

wget http://download.tizen.org/releases/weekly/tizen/unified/tizen-unified_20190807.5/builddata/manifest/tizen-unified_20190807.5_standard_preloadapp.xml -O .repo/manifests/unified/standard/projects.xml

echo "step 3. modify some line's information in the unified xml file"

sed -i '3,4d' .repo/manifests/unified/standard/projects.xml

echo 'step 4. repo sync'

repo sync -j 4

echo 'step 5. copy .gbs.conf file what is already modified for rp3 already'

cp /root/tizen_project/repo-script/.gbs.conf /root/tizen_src
