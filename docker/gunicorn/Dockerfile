FROM ubuntu:18.04

RUN apt-get update
RUN apt-get -y upgrade
# curl/wget/git
RUN apt-get install -y curl wget git tar
# vim
RUN apt-get install -y vim 
# C
RUN apt-get install -y build-essential gcc

# Python
RUN apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev
RUN cd /usr/src ; wget https://www.python.org/ftp/python/3.7.1/Python-3.7.1.tar.xz ; tar -xf Python-3.7.1.tar.xz ; cd Python-3.7.1 ; ./configure ; make altinstall

# be sure it's 3.7 and not 3.6
RUN ! ls /usr/local/bin/python3.7 && ls /usr/src/Python-3.7.1/python && cp /usr/src/Python-3.7.1/python /usr/local/bin/python3.7 ; exit 0

# replace python version to have 3.7.3 as default
RUN rm -f /usr/bin/python
RUN rm -f /usr/bin/python3
RUN ln -s /usr/local/bin/python3.7 /usr/bin/python
RUN ln -s /usr/local/bin/python3.7 /usr/bin/python3
RUN ln -s /usr/local/bin/python3.7 /usr/local/bin/python
RUN ln -s /usr/local/bin/python3.7 /usr/local/bin/python3

# create links to pip3.7
RUN ln -s /usr/local/bin/pip3.7 /usr/bin/pip
RUN ln -s /usr/local/bin/pip3.7 /usr/bin/pip3
RUN ln -s /usr/local/bin/pip3.7 /usr/local/bin/pip
RUN ln -s /usr/local/bin/pip3.7 /usr/local/bin/pip3

#update apt-get 
RUN apt-get update && apt-get -y upgrade
RUN pip install --upgrade pip
RUN pip3 install --upgrade pip

RUN apt-get install -y python3-dev libmysqlclient-dev

# SQLAlchemy
RUN pip3 install SQLAlchemy
RUN pip3 install sqlalchemy
RUN pip3 install sqlalchemy --upgrade
RUN pip3 install mysqlclient

# gunicorn
RUN pip3 install gunicorn

# pip3 package
RUN pip3 install virtualenv
RUN pip3 install django

# Set the locale
RUN apt-get install -y locales language-pack-ko
RUN locale-gen ko_KR.UTF-8
ENV LANG ko_KR.UTF-8
ENV LANGUAGE ko_KR:kr
ENV LC_ALL ko_KR.UTF-8

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 
ADD run.sh /tmp/run.sh
RUN chmod u+x /tmp/run.sh

# start run!
#CMD ["/tmp/run.sh"]

