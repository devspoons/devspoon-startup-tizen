cd ~/
ls -al
chown jenkins:jenkins .ssh -R
exit
ls
cd ~/.ssh/
ls
ls -al
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub  
touch authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/known_hosts
ls
vim id_rsa.pub 
cat id_rsa.pub 
ls
echo "" > known_hosts 
ls
ssh root@tizenenv
exit
cd ~/.ssh/
ls
cat id_rsa.pub 
ssh root@tizenenv
cd ~/
ls
ssh root@tizenenv
exit
cd ~/.ssh/
ls
ssh root@tizenenv
ls
rm test.txt 
cat known_hosts 
exit
ssh root@tizenenv
ls
cd ~/.ssh
ls
rm known_hosts 
ssh root@tizenenv
ls
rm known_hosts 
ssh-keygen -R tizenenv
ssh-keygen -R http://tizenenv
ssh-keygen -R tizenenv -f .ssh/known_hosts
ssh-keygen -R tizenenv -f ~/.ssh/known_hosts
ssh-keygen -R tizenenv -f ~/.ssh/known_hosts
ls
touch known_hosts
ssh-keygen -R tizenenv -f ~/.ssh/known_hosts
ssh-keygen -R tizenenv -f ~/.ssh/known_hosts
ssh-keygen -R tizenenv -f ~/.ssh/known_hosts
ping tizenenv
ssh-keygen -R tizenenv.master_service_default -f ~/.ssh/known_hosts
ssh root@tizenenv
exit
ssh-keyscan -t rsa tizenenv >> ~/.ssh/known_hosts
exit
ssh root@tizenenv
exit
