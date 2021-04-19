FROM tobi312/php:8.0-fpm
# https://hub.docker.com/r/tobi312/php

ENV OS_LOCALE="en_US.utf8" \
    DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} 	

RUN dpkg-reconfigure locales \
    && apt-get install --no-install-recommends -y software-properties-common wget gnupg \
    && apt-get install -y sendmail

RUN apt-get purge -y --auto-remove software-properties-common wget gnupg \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/* 	