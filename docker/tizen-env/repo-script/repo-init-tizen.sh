#!/bin/bash

set -e

echo 'step 1. repo init'

repo init -u ssh://tizen_account@review.tizen.org:29418/scm/manifest -b tizen -m unified_standard.xml

echo 'step 2. repo sync'

repo sync -j 4