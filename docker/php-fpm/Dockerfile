FROM romeoz/docker-phpfpm:7.3

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

RUN	\
	BUILD_DEPS='software-properties-common wget gnupg' \
	&& apt-get install --no-install-recommends -y $BUILD_DEPS \
    && apt-get install -y sendmail

RUN apt-get install -yq tzdata && \
    dpkg-reconfigure -f noninteractive tzdata

ENV TZ="Asia/Seoul"

RUN apt-get purge -y --auto-remove software-properties-common wget gnupg \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*