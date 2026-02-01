FROM ubuntu:20.04

# ========================================
# NOTE: Ubuntu 20.04 is required for Tizen SDK compatibility
# Tizen tools (gbs, mic) have specific Ubuntu version requirements
# ========================================

# ========================================
# 1. Environment configuration
# ========================================
ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"
ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/

# ========================================
# 2. Add Tizen repository and install base tools
# ========================================
RUN echo 'deb [trusted=yes] http://download.tizen.org/tools/latest-release/Ubuntu_20.04/ /' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-utils \
    git \
    wget \
    curl \
    vim \
    ssh \
    gbs \
    mic \
    python3 \
    python3-pip \
    build-essential \
    openssh-server \
    locales \
    software-properties-common \
    ca-certificates

# ========================================
# 3. Locale configuration
# ========================================
RUN localedef -i ${OS_LOCALE_COUNTRY} -f ${OS_LOCALE_ENCODING} ${OS_LOCALE}

ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    LC_CTYPE=${OS_LOCALE} \
    LC_MESSAGES=${OS_LOCALE}

# ========================================
# 4. Install OpenJDK 11 (LTS version)
# ========================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-11-jdk \
    ant \
    ca-certificates-java && \
    update-ca-certificates -f

# ========================================
# 5. Cleanup APT cache
# ========================================
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ========================================
# 6. SSH configuration
# ========================================
RUN sed -i 's/^AcceptEnv LANG LC_\*$//g' /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd

ADD system/sshd_config /etc/ssh/sshd_config

# ========================================
# 7. Git configuration
# IMPORTANT: Replace USERNAME and E-MAIL with your actual values
# ========================================
RUN git config --global user.name "USERNAME" && \
    git config --global user.email "E-MAIL" && \
    git config --global color.ui true

# ========================================
# 8. Setup PATH
# ========================================
RUN mkdir -p ~/bin && \
    echo 'PATH=~/bin:$PATH' >> ~/.bashrc

# ========================================
# 9. Copy SSH keys and scripts
# ========================================
COPY .ssh /root/.ssh

RUN chmod 700 /root/.ssh/ && \
    chmod 644 /root/.ssh/* && \
    chmod 600 /root/.ssh/id_rsa

ADD repo-script/ /root/repo-script/
ADD samples/ /root/samples/
ADD build-script/ /root/build-script/

ENTRYPOINT ["/usr/sbin/sshd", "-D"]
