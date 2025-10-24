FROM ubuntu:latest

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils

ENV TZ=Asia/Seoul

RUN apt-get install -yq tzdata 
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# curl/wget/git/gnupg2/lsb-release/lz4/zstd
RUN apt-get install -y curl wget git tar gnupg2 lsb-release lz4 zstd
# vim
RUN apt-get install -y vim

# Python
RUN apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev
RUN cd /usr/src ; wget https://www.python.org/ftp/python/3.14.0/Python-3.14.0.tar.xz  ; tar -xf Python-3.14.0.tar.xz ; cd Python-3.14.0 ; ./configure ; make altinstall

# be sure it's 3.14.0
RUN ! ls /usr/local/bin/python3.14.0 && ls /usr/src/Python-3.14.0/python && cp /usr/src/Python-3.14.0/python /usr/local/bin/python3.14.0 ; exit 0

# replace python version to have 3.14.0 as default
RUN rm -f /usr/bin/python
RUN rm -f /usr/bin/python3
RUN ln -s /usr/local/bin/python3.14.0 /usr/bin/python
RUN ln -s /usr/local/bin/python3.14.0 /usr/bin/python3
RUN ln -s /usr/local/bin/python3.14.0 /usr/local/bin/python
RUN ln -s /usr/local/bin/python3.14.0 /usr/local/bin/python3

ENV PYTHONUNBUFFERED=1

# create links to pip3.12
RUN ln -s /usr/local/bin/pip3.14 /usr/bin/pip
RUN ln -s /usr/local/bin/pip3.14 /usr/bin/pip3
RUN ln -s /usr/local/bin/pip3.14 /usr/local/bin/pip
RUN ln -s /usr/local/bin/pip3.14 /usr/local/bin/pip3

#update apt-get
RUN apt-get update && apt-get -y upgrade
RUN pip install --upgrade pip
RUN pip3 install --upgrade pip

RUN apt-get install -y python3-dev libmysqlclient-dev pkg-config

RUN pip3 install wheel

# SQLAlchemy
RUN pip3 install sqlalchemy alembic pydantic

# postgresql 동기 / 비동기
RUN pip3 install psycopg2-binary asyncpg 

# mysql 동기 / 비동기
RUN pip3 install mysqlclient asyncmy

# mysql 백업
RUN curl -O https://repo.percona.com/apt/percona-release_latest.generic_all.deb
RUN apt-get install -y ./percona-release_latest.generic_all.deb
RUN apt update
RUN percona-release enable pxb-84-lts
RUN apt-get install -y percona-xtrabackup-84

# postgresql 백업
RUN apt-get -y install pgbackrest

# gunicorn & uvicorn 
RUN pip3 install gunicorn uvicorn[standard]

# pip3 package
RUN pip3 install fastapi uv

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN update-ca-certificates
