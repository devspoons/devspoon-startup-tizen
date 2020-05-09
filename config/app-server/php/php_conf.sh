#!/bin/bash

account=$1
port=$2


sed 's/account/'$account'/' sample_php.conf > $account'1'.temp
sed 's/port/'$port'/' $account'1'.temp > ./pool.d/$account'_php'.conf

rm *.temp