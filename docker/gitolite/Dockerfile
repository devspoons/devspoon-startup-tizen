FROM ubuntu:18.04

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils
# vim
RUN apt-get install -y vim wget openssh-server git locales

# Set the locale
#RUN apt-get install -y locales language-pack-ko
# RUN locale-gen ko_KR.UTF-8
# ENV LANG ko_KR.UTF-8
# ENV LANGUAGE ko_KR:kr
# ENV LC_ALL ko_KR.UTF-8

ENV OS_LOCALE="en_US.utf8" \
    DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} 

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

RUN sed -i 's/^AcceptEnv LANG LC_\*$//g' /etc/ssh/sshd_config

RUN mkdir /var/run/sshd

ADD system/sshd_config /etc/ssh/sshd_config

RUN adduser --system --group --disabled-password --gecos "" --shell /bin/bash --home /home/gitolite-creator gitolite-creator

#RUN echo gitolite-creator:1324 | chpasswd

RUN adduser --disabled-password --gecos "" --shell /bin/bash --home /home/git-manager git-manager

#RUN echo git-manager:1324 | chpasswd

#RUN su git-manager -c "mkdir /home/git-manager/.ssh"

RUN su git-manager -c "ssh-keygen -f /home/git-manager/.ssh/git-manager -b 4096 -t rsa -N ''"

ADD system/id_rsa.pub /home/git-manager/.ssh/authorized_keys

ADD system/id_rsa.pub /home/git-manager/id_rsa.pub

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
