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

#RUN	 apt-get install -y php7.3-mbstring
#RUN	 apt-get install -y php7.3-gd 
#RUN	 apt-get install -y php7.3-curl 
#RUN	 apt-get install --no-install-recommends -y php7.3-xml
#RUN	 apt-get install --no-install-recommends -y php7.3-bcmath
#RUN	 apt-get install --no-install-recommends -y php7.3-mysql 
#RUN	 apt-get install --no-install-recommends -y composer

RUN	apt-get purge -y --auto-remove $BUILD_DEPS \
	&& apt-get autoremove -y && apt-get clean \
	&& rm -rf /var/lib/apt/lists/* 	
	
RUN ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
#RUN chown www-data:www-data /www/ -Rf 

#COPY ./configs/nginx.conf ${NGINX_CONF_DIR}/nginx.conf
#COPY ./configs/app.conf ${NGINX_CONF_DIR}/sites-enabled/app.conf
#COPY ./configs/www.conf /etc/php/7.3/fpm/pool.d/www.conf

#WORKDIR /var/www/app/

#EXPOSE 80 443