FROM php:8.3-fpm

# ========================================
# 1. Environment configuration
# ========================================
ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"
ENV TZ="Asia/Seoul"
ENV DEBIAN_FRONTEND=noninteractive

# ========================================
# 2. APT update and install base tools
# ========================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-utils \
    tzdata \
    curl \
    wget \
    git \
    tar \
    vim \
    locales \
    sendmail \
    gnupg \
    ca-certificates

# ========================================
# 3. Timezone configuration
# ========================================
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# ========================================
# 4. Locale configuration
# ========================================
RUN localedef -i ${OS_LOCALE_COUNTRY} -f ${OS_LOCALE_ENCODING} ${OS_LOCALE}

ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    LC_CTYPE=${OS_LOCALE} \
    LC_MESSAGES=${OS_LOCALE}

# ========================================
# 5. Install PHP extensions dependencies
# ========================================
RUN apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    default-mysql-client \
    libmariadb-dev

# ========================================
# 6. Install PHP extensions
# ========================================
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    gd \
    zip \
    intl \
    mbstring \
    xml \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    mysqli \
    opcache

# ========================================
# 7. Install Composer
# ========================================
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# ========================================
# 8. Cleanup
# ========================================
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    update-ca-certificates
