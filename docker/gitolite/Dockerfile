FROM ubuntu:20.04

RUN apt update
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends apt-utils vim wget openssh-server git locales

# Set the locale
ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"

RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends locales 
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    LC_CTYPE=${OS_LOCALE} \
    LC_MESSAGES=${OS_LOCALE}

RUN apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN sed -i 's/^AcceptEnv LANG LC_\*$//g' /etc/ssh/sshd_config

RUN mkdir /var/run/sshd

ADD system/sshd_config /etc/ssh/sshd_config

RUN adduser --system --group --disabled-password --gecos "" --shell /bin/bash --home /home/gitolite-creator gitolite-creator

#RUN echo gitolite-creator:1324 | chpasswd

RUN adduser --disabled-password --gecos "" --shell /bin/bash --home /home/git-manager git-manager

#RUN echo git-manager:1324 | chpasswd

#RUN su git-manager -c "mkdir /home/git-manager/.ssh"

RUN su git-manager -c "ssh-keygen -f /home/git-manager/.ssh/git-manager -b 4096 -t rsa -N ''"

ADD system/client_user.pub /home/git-manager/.ssh/authorized_keys

ADD system/client_user.pub /home/git-manager/client_user.pub

ADD system/config /home/git-manager/.ssh/config

ADD sample-script /home/git-manager/sample-script

RUN chmod +x /home/git-manager/sample-script/*

RUN chown git-manager:git-manager /home/git-manager* -R

RUN cp /home/git-manager/.ssh/git-manager.pub /home/gitolite-creator/gitolite-creator.pub

WORKDIR /home/gitolite-creator

RUN su gitolite-creator -c "mkdir bin"

RUN su gitolite-creator -c "git clone git://github.com/sitaramc/gitolite"

RUN su gitolite-creator -c "gitolite/install -to /home/gitolite-creator/bin"

RUN su gitolite-creator -c "bin/gitolite setup -pk gitolite-creator.pub"

RUN chown gitolite-creator:gitolite-creator /home/gitolite-creator/* -R

CMD ["/usr/sbin/sshd", "-D"]
