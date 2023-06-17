FROM ubuntu:latest

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils

# curl/wget/git
RUN apt-get install -y curl wget git tar
# vim
RUN apt-get install -y vim
# C
RUN apt-get install -y build-essential gcc

# Python
RUN apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev
RUN cd /usr/src ; wget https://www.python.org/ftp/python/3.11.4/Python-3.11.4.tar.xz  ; tar -xf Python-3.11.4.tar.xz ; cd Python-3.11.4 ; ./configure ; make altinstall

# be sure it's 3.11.4
RUN ! ls /usr/local/bin/python3.11.4 && ls /usr/src/Python-3.11.4/python && cp /usr/src/Python-3.11.4/python /usr/local/bin/python3.11.4 ; exit 0

# replace python version to have 3.11.4 as default
RUN rm -f /usr/bin/python
RUN rm -f /usr/bin/python3
RUN ln -s /usr/local/bin/python3.11.4 /usr/bin/python
RUN ln -s /usr/local/bin/python3.11.4 /usr/bin/python3
RUN ln -s /usr/local/bin/python3.11.4 /usr/local/bin/python
RUN ln -s /usr/local/bin/python3.11.4 /usr/local/bin/python3

# create links to pip3.11
RUN ln -s /usr/local/bin/pip3.11 /usr/bin/pip
RUN ln -s /usr/local/bin/pip3.11 /usr/bin/pip3
RUN ln -s /usr/local/bin/pip3.11 /usr/local/bin/pip
RUN ln -s /usr/local/bin/pip3.11 /usr/local/bin/pip3

#update apt-get
RUN apt-get update && apt-get -y upgrade
RUN pip install --upgrade pip
RUN pip3 install --upgrade pip

RUN apt-get install -y python3-dev libmysqlclient-dev

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

ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils

RUN apt-get install -y --no-install-recommends locales

RUN localedef -i ${OS_LOCALE_COUNTRY} -f ${OS_LOCALE_ENCODING} ${OS_LOCALE}

ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    LC_CTYPE=${OS_LOCALE} \
    LC_MESSAGES=${OS_LOCALE}

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
