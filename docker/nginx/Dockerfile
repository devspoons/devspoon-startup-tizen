FROM nginx:latest

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

RUN apt-get install -yq tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

ENV TZ="Asia/Seoul"

RUN	\
    BUILD_DEPS='software-properties-common wget gnupg' \
    && apt-get install --no-install-recommends -y $BUILD_DEPS \
    && apt-get install -y sendmail \
    && apt-get install -y cron certbot \
    && apt-get install wget
# Cleaning
RUN	apt-get purge -y --auto-remove $BUILD_DEPS \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN wget --no-check-certificate https://curl.haxx.se/ca/cacert.pem

RUN cp cacert.pem  /etc/ssl/certs/ca-certificates.crt

RUN crontab -l | { cat; echo "0 5 * * 1 certbot renew --quiet --renew-hook \"service nginx restart\" > /log/nginx/crontab_$(date +\%Y\%m\%d).log 2>&1"; } | crontab -

RUN sed -i'' -r -e "/set/i\cron" docker-entrypoint.sh

RUN cp cacert.pem  /etc/ssl/certs/ca-certificates.crt