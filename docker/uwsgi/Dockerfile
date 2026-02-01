FROM ubuntu:24.04

# ========================================
# 1. Base setup and timezone configuration
# ========================================
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHON_VERSION=3.13.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends apt-utils && \
    apt-get install -yq tzdata && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ========================================
# 2. Install essential tools
# ========================================
RUN apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    tar \
    gnupg2 \
    lsb-release \
    lz4 \
    zstd \
    vim \
    ca-certificates

# ========================================
# 3. Install Python build dependencies and compile Python
# ========================================
RUN apt-get install -y --no-install-recommends \
    build-essential \
    zlib1g-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    liblzma-dev && \
    cd /usr/src && \
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz && \
    tar -xf Python-${PYTHON_VERSION}.tar.xz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations && \
    make -j$(nproc) altinstall && \
    rm -rf /usr/src/Python-${PYTHON_VERSION} /usr/src/Python-${PYTHON_VERSION}.tar.xz

# ========================================
# 4. Setup Python symlinks
# ========================================
RUN rm -f /usr/bin/python /usr/bin/python3 && \
    ln -s /usr/local/bin/python3.13 /usr/bin/python && \
    ln -s /usr/local/bin/python3.13 /usr/bin/python3 && \
    ln -s /usr/local/bin/python3.13 /usr/local/bin/python && \
    ln -s /usr/local/bin/python3.13 /usr/local/bin/python3

# ========================================
# 5. Setup pip symlinks
# ========================================
RUN ln -s /usr/local/bin/pip3.13 /usr/bin/pip && \
    ln -s /usr/local/bin/pip3.13 /usr/bin/pip3 && \
    ln -s /usr/local/bin/pip3.13 /usr/local/bin/pip && \
    ln -s /usr/local/bin/pip3.13 /usr/local/bin/pip3

# ========================================
# 6. Upgrade pip and install wheel
# ========================================
RUN pip install --no-cache-dir --upgrade pip wheel

# ========================================
# 7. Install MySQL client dependencies
# ========================================
RUN apt-get install -y --no-install-recommends \
    python3-dev \
    libmysqlclient-dev \
    pkg-config

# ========================================
# 8. Install Python packages - ORM and Database drivers
# ========================================
RUN pip3 install --no-cache-dir \
    sqlalchemy \
    alembic \
    pydantic \
    psycopg2-binary \
    asyncpg \
    mysqlclient \
    asyncmy

# ========================================
# 9. Install MySQL backup tool (Percona XtraBackup)
# ========================================
RUN curl -O https://repo.percona.com/apt/percona-release_latest.generic_all.deb && \
    apt-get install -y ./percona-release_latest.generic_all.deb && \
    rm -f percona-release_latest.generic_all.deb && \
    apt-get update && \
    percona-release enable pxb-84-lts && \
    apt-get install -y percona-xtrabackup-84

# ========================================
# 10. Install PostgreSQL backup tool
# ========================================
RUN apt-get install -y --no-install-recommends pgbackrest

# ========================================
# 11. Install Python web frameworks and tools
# ========================================
RUN pip3 install --no-cache-dir \
    gunicorn \
    "uvicorn[standard]" \
    uwsgi \
    django \
    poetry \
    uv

# ========================================
# 12. Cleanup
# ========================================
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    update-ca-certificates
