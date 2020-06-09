#!/bin/bash

git config --global user.email "testuser@testuser.com"
git config --global user.name "testuser"

#add new user
mv ~/id_rsa.pub ~/gitolite-admin/keydir/testuser.pub
cd ~/gitolite-admin
git add *
git commit -a -m "user testuser add"
git push origin master
