FROM ubuntu:18.04

RUN echo 'deb [trusted=yes] http://download.tizen.org/tools/latest-release/Ubuntu_18.04/ /' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y git wget curl vim ssh gbs mic python python-pip build-essential && \    
    apt-get update && \
    apt-get clean

EXPOSE 22

RUN apt-get autoremove -y && apt-get clean \
	&& rm -rf /var/lib/apt/lists/* 	

RUN git config --global user.name " id ex) test_tizen " 
RUN git config --global user.email " email ex) test_tizen@gmail.com "
RUN git config --global color.ui true

RUN mkdir ~/bin/
RUN echo 'PATH=~/bin:$PATH' >> ~/.bashrc

RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ~/bin/repo && \
    chmod a+x ~/bin/repo

COPY .ssh /root/.ssh

RUN chmod 700 /root/.ssh/ && chmod 644 /root/.ssh/* && chmod 600 /root/.ssh/id_rsa

RUN mkdir /root/tizen_project

ADD repo-script/ /root/tizen_project/repo-script/

RUN chmod 777 /root/tizen_project/repo-script/*

ADD catalina.sh /usr/local/bin/catalina.sh

RUN chmod 777 /usr/local/bin/catalina.sh

ENTRYPOINT ["/usr/local/bin/catalina.sh"]
