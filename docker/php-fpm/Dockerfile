FROM tobi312/php:8.0-fpm
# https://hub.docker.com/r/tobi312/php

ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils

RUN apt-get install -y --no-install-recommends locales

ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    LC_CTYPE=${OS_LOCALE} \
    LC_MESSAGES=${OS_LOCALE}

RUN	\
	BUILD_DEPS='software-properties-common wget gnupg' \
	&& apt-get install --no-install-recommends -y $BUILD_DEPS \
    && apt-get install -y sendmail \
    && apt-get install -y cron \
    && apt-get install -y certbot

RUN apt-get install -yq tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

ENV TZ="Asia/Seoul"

RUN apt-get purge -y --auto-remove software-properties-common wget gnupg \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*