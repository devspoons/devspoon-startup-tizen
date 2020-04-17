#!/bin/bash

repo init -u ssh://tizen_account@review.tizen.org:29418/scm/manifest -b tizen -m unified_standard.xml

repo sync -j 16