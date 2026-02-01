FROM ubuntu:24.04

# ========================================
# 1. Environment configuration
# ========================================
ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"
ENV DEBIAN_FRONTEND=noninteractive

# ========================================
# 2. APT update and install base tools
# ========================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-utils \
    vim \
    wget \
    openssh-server \
    git \
    locales

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
# 4. Cleanup APT cache
# ========================================
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ========================================
# 5. SSH configuration
# ========================================
RUN sed -i 's/^AcceptEnv LANG LC_\*$//g' /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd

ADD system/sshd_config /etc/ssh/sshd_config

# ========================================
# 6. Create gitolite-creator user
# ========================================
RUN adduser --system --group --disabled-password --gecos "" --shell /bin/bash --home /home/gitolite-creator gitolite-creator

# ========================================
# 7. Create git-manager user and setup SSH keys
# ========================================
RUN adduser --disabled-password --gecos "" --shell /bin/bash --home /home/git-manager git-manager && \
    su git-manager -c "ssh-keygen -f /home/git-manager/.ssh/git-manager -b 4096 -t rsa -N ''"

ADD system/client_user.pub /home/git-manager/.ssh/authorized_keys
ADD system/client_user.pub /home/git-manager/client_user.pub
ADD system/config /home/git-manager/.ssh/config
ADD sample-script /home/git-manager/sample-script

RUN chmod +x /home/git-manager/sample-script/* && \
    chown -R git-manager:git-manager /home/git-manager

# ========================================
# 8. Setup gitolite
# ========================================
RUN cp /home/git-manager/.ssh/git-manager.pub /home/gitolite-creator/gitolite-creator.pub

WORKDIR /home/gitolite-creator

RUN su gitolite-creator -c "mkdir bin" && \
    su gitolite-creator -c "git clone git://github.com/sitaramc/gitolite" && \
    su gitolite-creator -c "gitolite/install -to /home/gitolite-creator/bin" && \
    su gitolite-creator -c "bin/gitolite setup -pk gitolite-creator.pub" && \
    chown -R gitolite-creator:gitolite-creator /home/gitolite-creator

CMD ["/usr/sbin/sshd", "-D"]
