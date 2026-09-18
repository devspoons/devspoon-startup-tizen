FROM ubuntu:24.04

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends apt-utils vim wget openssh-server git ca-certificates locales

# Set the locale
ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"

RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends locales

RUN localedef -i ${OS_LOCALE_COUNTRY} -f ${OS_LOCALE_ENCODING} ${OS_LOCALE}

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
# sample-script(clone_admin.sh·add_user.sh)가 컨테이너 안 sshd(localhost)에 처음 붙을 때 호스트 키 확인 프롬프트에서 멈추지 않도록
# (비대화형 실행 시 "Host key verification failed"), 이미지에 생성된 sshd 호스트 공개키를 git-manager 의 known_hosts 에 등록한다.
RUN for k in /etc/ssh/ssh_host_*_key.pub; do echo "localhost $(cut -d' ' -f1,2 "$k")"; done > /home/git-manager/.ssh/known_hosts \
 && test -s /home/git-manager/.ssh/known_hosts

ADD sample-script /home/git-manager/sample-script

RUN chmod +x /home/git-manager/sample-script/*

RUN chown git-manager:git-manager /home/git-manager* -R

RUN cp /home/git-manager/.ssh/git-manager.pub /home/gitolite-creator/gitolite-creator.pub

WORKDIR /home/gitolite-creator

RUN su gitolite-creator -c "mkdir bin"

RUN su gitolite-creator -c "git clone -b v3.6.15 https://github.com/sitaramc/gitolite"

RUN su gitolite-creator -c "gitolite/install -to /home/gitolite-creator/bin"

RUN su gitolite-creator -c "bin/gitolite setup -pk gitolite-creator.pub"

RUN chown gitolite-creator:gitolite-creator /home/gitolite-creator/* -R

CMD ["/usr/sbin/sshd", "-D"]
