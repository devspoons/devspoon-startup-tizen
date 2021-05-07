FROM ubuntu:20.04

RUN apt update
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends apt-utils

# curl/wget/git
RUN apt install -y curl wget git tar
# vim
RUN apt install -y vim 
# C
RUN apt install -y build-essential gcc

# Python
RUN apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev
RUN cd /usr/src ; wget https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tar.xz ; tar -xf Python-3.8.5.tar.xz ; cd Python-3.8.5 ; ./configure ; make altinstall

# be sure it's 3.8 and not 3.6
RUN ! ls /usr/local/bin/python3.8 && ls /usr/src/Python-3.8.5/python && cp /usr/src/Python-3.8.5/python /usr/local/bin/python3.8 ; exit 0

# replace python version to have 3.8.5 as default
RUN rm -f /usr/bin/python
RUN rm -f /usr/bin/python3
RUN ln -s /usr/local/bin/python3.8 /usr/bin/python
RUN ln -s /usr/local/bin/python3.8 /usr/bin/python3
RUN ln -s /usr/local/bin/python3.8 /usr/local/bin/python
RUN ln -s /usr/local/bin/python3.8 /usr/local/bin/python3

# create links to pip3.8
RUN ln -s /usr/local/bin/pip3.8 /usr/bin/pip
RUN ln -s /usr/local/bin/pip3.8 /usr/bin/pip3
RUN ln -s /usr/local/bin/pip3.8 /usr/local/bin/pip
RUN ln -s /usr/local/bin/pip3.8 /usr/local/bin/pip3

#update apt 
RUN apt update && apt -y upgrade
RUN pip install --upgrade pip
RUN pip3 install --upgrade pip

RUN apt install -y python3-dev libmysqlclient-dev

RUN pip3 install wheel

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
# RUN apt install -y locales language-pack-ko
# RUN locale-gen ko_KR.UTF-8
# ENV LANG ko_KR.UTF-8
# ENV LANGUAGE ko_KR:kr
# ENV LC_ALL ko_KR.UTF-8

ENV OS_LOCALE="en_US.utf8" \
    DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y locales && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} 

RUN apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
