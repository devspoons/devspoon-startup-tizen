FROM romeoz/docker-phpfpm:7.3

ENV OS_LOCALE="en_US.utf8" \
    DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} 	

RUN	\
	BUILD_DEPS='software-properties-common wget gnupg' \
    && dpkg-reconfigure locales \
	&& apt-get install --no-install-recommends -y $BUILD_DEPS \    	 
    && apt-get install -y sendmail
	# Cleaning

RUN	apt-get purge -y --auto-remove $BUILD_DEPS \
	&& apt-get autoremove -y && apt-get clean \
	&& rm -rf /var/lib/apt/lists/* 	
	
RUN ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime