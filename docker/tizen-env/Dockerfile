FROM ubuntu:18.04

RUN echo 'deb [trusted=yes] http://download.tizen.org/tools/latest-release/Ubuntu_18.04/ /' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y git wget curl vim ssh gbs mic python python-pip build-essential openssh-server locales repo && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils && \
    apt-get clean;

# Set the locale
ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils

RUN apt-get install -y --no-install-recommends locales

ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    LC_CTYPE=${OS_LOCALE} \
    LC_MESSAGES=${OS_LOCALE}

# Install "software-properties-common" (for the "add-apt-repository")
RUN apt-get update && \
    apt-get install -y \
    software-properties-common && \
    apt-get clean;

# Add the "JAVA" ppa
RUN add-apt-repository -y \
    ppa:webupd8team/java

RUN apt-get --allow-releaseinfo-change update

# Install OpenJDK-8
RUN apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    apt-get install -y ant && \
    apt-get clean;

# Fix certificate issues
RUN apt-get update && \
    apt-get install ca-certificates-java && \
    apt-get clean && \
    update-ca-certificates -f;

# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

RUN apt-get autoremove -y && apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN sed -i 's/^AcceptEnv LANG LC_\*$//g' /etc/ssh/sshd_config

RUN mkdir /var/run/sshd

ADD system/sshd_config /etc/ssh/sshd_config

#ex) test_tizen
RUN git config --global user.name "USERNAME"

#ex) test_tizen@gmail.com
RUN git config --global user.email "E-MAIL"

RUN git config --global color.ui true

RUN mkdir ~/bin/
RUN echo 'PATH=~/bin:$PATH' >> ~/.bashrc

COPY .ssh /root/.ssh

RUN chmod 700 /root/.ssh/ && chmod 644 /root/.ssh/* && chmod 600 /root/.ssh/id_rsa

ADD repo-script/ /root/repo-script/

ADD samples/ /root/samples/

ADD build-script/ /root/build-script/

ENTRYPOINT ["/usr/sbin/sshd","-D"]
