# devspoon-startup-tizen
-devspoon-startup-tizen is an open source solution that can easily build a reliable Tizen development environment using Docker.  

devspoon-startup-tizen made with the web service building solution supporting php, python based on nginx named [devspoon-web] and integrated management solution(openproject, jenkins, gitolite[private git server], harbor[private docker server]) of project named [devspoon-startup-web].  

devspoon-startup-tizen can easily build the complex configuration required to develop Samsung Tizen-based IoT devices using the already verified Dockerfile and Docker-compose.  
Development automation (CI:Continuous Integration) can be configured using jenkins provided as [devspoon-startup-web], and projects can be efficiently managed with openproject.  
Gitolite is linked with openproject and jenkins, and can be used efficiently without repository public and limitations on the capacity restriction of git server and public storage.  
Using the harbor, you can build an independent docker image according to the type, version, and kernel environment type of the smart TV, IoT development board, and download and install the docker image to any new server at any time from the docker hub.  
By configuring devspoon-startup-tizen, when moving to the internal network, you can build a development environment under various conditions and manage sources and projects even when there is no Internet connection.  

The nginx web server provided as [devspoon-web] supports automatic creation of http/https/Reverse-proxy conf files using shell scripts, and can access project management solutions using domains.  
You can download and management of the finally created Tizen image from a Tizen image management solution developed by our self.

devspoon-startup-tizen은 신뢰할 수 있는 Tizen 개발환경을 Docker를 이용하여 쉽게 구축할 수 있는 오픈소스 솔루션입니다.  

devspoon-startup-tizen은 nginx 기반의 php, python 웹 서비스 구축 솔루션 [devspoon-web]와 프로젝트 통합 관리 솔루션(openproject, jenkins, gitolite[private git server], harbor[private docker server]) [devspoon-startup-web]을 기반으로 만들어졌습니다.  

devspoon-startup-tizen은 삼성 Tizen 기반의 IoT 장비들을 개발하기 위해 요구되는 복잡한 환경설정을 이미 검증된 Dockerfile과 Docker-compose를 이용해 쉽게 구축을 할 수 있습니다.   

[devspoon-startup-web]으로 제공되는 jenkins를 이용해 개발 자동화(CI:Continuous Integration)를 구성할 수 있으며 openproject로 프로젝트들을 효율적으로 관리할 수 있습니다.   
함께 제공되는 gitolite는 openproject, jenkins와 연동이되며 git server의 용량 제한 및 저장소 공개에 제한, 제약없이 효율적으로 사용가능합니다.   
harbor를 이용해 스마트 TV, IoT 개발보드의 종류, 버전 및 커널 환경의 종류 등에 따라 독립적인 docker 이미지를 빌드, docker hub로 부터 언제 어느 서버에서도 docker 이미지를 다운로드 받아 설치할 수 있습니다.   
devspoon-startup-tizen를 구성하여 내부망으로 이전시, 인터넷이 연결되지 않는 환경에서도 다양한 조건의 개발 환경을 구축, 소스 및 프로젝트를 관리할 수 있습니다.   

[devspoon-web]로 제공되는 nginx 웹서버는 shell script를 이용하여 http/https/Reverse Proxy의 conf 파일 자동생성을 지원하며 도메인을 이용하여 프로젝트 관리 솔루션들에 접근할 수 있습니다.  
최종적으로 만들어진 Tizen 이미지의 다운로드 및 관리를 자체 개발되어 제공되는 Tizen 이미지 관리 솔루션으로 제공받을 수 있습니다.

* You can get more informations at [devspoons.github.io]

## Project management solutions

* **[OpenProject] :** Open source project management software to help you work on your project efficiently

* **[Jenkins] :** As one of the CI tools, CI (Continuous Integration) refers to continuous integration, which is an automated process for developers, and new code changes are automatically built and tested regularly to notify developers to solve problems that can occur when multiple developers develop simultaneously. Software that helps secure development stability and reliability

* **[Gitolite] :** Configuration Management Tool. user can install git server software at own server

* **[Harbor] :** The Private Docker Registry Server for businesses that store and distribute Docker Images

* **[OpenProject(KR)] :** 프로젝트를 효율적으로 진행할 수 있도록 지원하는 오픈 소스 프로젝트 관리 소프트웨어

* **[Jenkins(KR)] :** CI 툴 중 하나로 CI (Continuous Integration)는 개발자를 위한 자동화 프로세스인 지속적인 통합을 말하며 새로운 코드 변경 사항들이 정기적으로 자동 빌드 및 테스트되어 개발자에게 알려줌으로 여러명의 개발자가 동시에 개발하며 발생할 수 있는 문제들을 해결하여 개발의 안정성 및 신뢰성을 확보할 수 있도록 지원하는 소프트웨어

* **[Gitolite] :** 형상 관리 도구 혹은 버전관리 시스템으로 자체적으로 설치하고 운영할 수 있는 git 소프트웨어

* **[Harbor(KR)] :**  Docker Image를 저장하고 분배하는 기업용 Private Docker Registry Server

## Features

* **Support to make configuration files for each service(conf, yml etc)** : Using shell script, you can easily make and manage the configuration files required for nginx, php, dockerfile, etc. with only the information required by the user's keyboard.

* **Efficiently  dockerfile configuration for development and service operation** : The log folder is interlocked by "volumes" in docker-compose.yml so that user can can be tracked problems even when the docker container is stopped. Webroot, nginx config, etc. are frequently modified during development so these are interlocked by "volumes" 

* **Provide reverse proxy function** : Multiple web and app services can be provided through one nginx with php or python and services can be provided simultaneously. A shell script is provided to easily create a proxy config file so that it can be integrated with the web UI of other services.

* **Provides easy distributed service operation method** : You can use multiple web servers through proxy, and you can use multiple app servers on one web server. (How to set load balancing will be supported in the future)

* **각 서비스들의 환경설정 파일 생성 지원(conf, yml etc)** : shell script를 이용해 nginx, php, dockerfile 등에 요구되는 환경설정 파일들을 필수적으로 요구되는 정보들만 사용자의 키보드로 입력받아 쉽게 만들고 관리할 수 있습니다.
  
* **개발 및 서비스 운영에 효율적인 dockerfile 구성** : docker container가 중지된 경우에도 문제를 추적할 수 있도록 log 폴더를 volumes으로 연동되어 있으며 Webroot, nginx의 config 등 개발시 수정이 빈번하게 발생되는 항목들에 대해서도 volumes으로 연동되어 있습니다.
  
* **Reverse proxy 기능 제공** : 하나의 nginx를 통해 여러개의 web, app 서비스를 제공하거나 php 혹은 python의 서비스를 동시에 제공할 수 있습니다. 다른 서비스의 웹 UI와 연동될 수 있도록 proxy config 파일을 쉽게 생성할 수 있도록 쉘 스크립트를 제공합니다.
  
* **쉬운 분산 서비스 운영 방법 제공** : proxy를 통해 여러대의 웹 서버를 사용할 수 있으며 하나의 웹 서버에서 여러대의 앱 서버를 사용할 수 있습니다. (부하분산을 설정 방법 차후 지원 예정)

## Considerations

* **No DB service** : This open source does not provide DB as docker to suggest stable operation. It is recommended to install it on a real server and access it using a network, such as port 3306. We hope that this will be done for distributed services as well. We hope that this will be consider for distributed services as well.

* **Development-oriented docker service** : This open source is designed for focused on development-oriented rather than perfect docker container distribution and is suitable for startups or new service development teams with frequent initial modifications and tests.

* **Orchestration not supported** : In the future, we plan to interoperate with cloud services such as AWS and GCM

* **This open-source considers generic servers that are not support AWS, GCM** : This open source is intended to be installed and operated on a server that is directly operated, and on general server hosting, and plans to integrate with cloud services such as AWS and GCM in the future

* **DB 서비스 없음** : 이 오픈소스는 안정적인 운영을 제안하기 위해 DB는 docker로 제공하지 않습니다. 실제 서버에 설치하여 3306 포트 등으로 네트워크를 이용해 접근하는 것을 권장합니다. 분산 서비스를 위해서라도 이와 같이 구성하기를 바랍니다.
  
* **개발 중심적 docker 서비스** : 이 오픈소스는 완전한 docker container의 배포가 아닌 개발 중심적으로 설계되었으며 초기 수정과 테스트가 빈번한 스타트업 혹은 신규 서비스 개발팀에게 적합합니다.
  
* **오케스트레이션 미지원** : 앞으로 AWS, GCM 등의 Cloud 서비스와 연동할 계획이며 이후 오케스트레이션이 지원될 예정입니다.
  
* **AWS, GCM 기반이 아닌 일반 서버 고려** : 이 오픈소스는 직접 운용하고있는 서버, 일반적인 서버 호스팅에서 설치하여 운영하는 것을 목적으로 하고 있으며 앞으로 단계적으로 AWS, GCM 등의 Cloud 서비스와 연동할 계획입니다.

## Install & Run

### How to build web services(PHP-v7.3, python[gunicorn, uwsgi])

* Refer the guide : [devspoon-web]

### How to build project management solutions(openproject, jenkins, gitolite[private git server], harbor[private docker server])

* Refer the guide : [devspoon-startup-web]
* I have sample code on junkins_home. If you want the reset environment, delete all the contents.
* Sample Jenkins account info **ID: admin PASSWORD: 1324**

### How to build Tizen development environment

* Build GBS(Tizen Build Server) by user self : https://source.tizen.org/documentation/developer-guide/all-one-instructions/creating-tizen-images-scratch-one-page
* Interlock GBS(Tizen Build Server) with jenkins(CI)  by user self : https://source.tizen.org/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework

1. Prepare ssh key

   * Register a user account at [tizen web-site]. 
   * A user have to make ssh key to using ssh-keygen to register on tizen development official website for accessing tizen repository.
   * Log in to Tizen Gerrit(https://review.tizen.org/gerrit) and upload the key
      * In the Gerrit(https://review.tizen.org/gerrit) Web page, get login and go click settings and add your id_rsa.pub at the menu of "SSH Public Keys".
   * A user have to copy made ssh keys to docker/tizen-env/.ssh.
   * If A user want to access tizen container directly for development, can add new location of "volumes" in a docker-compose.yml.
   * If A user want to access tizen container by ssh for development, make a new ssh key and add your pub key to an end of authorized_keys at docker/tizen-env/.ssh. if there are no authorized_keys, A user have to make this file.


2. Update Tizen ssh config file 
    * docker/tizen-env/.ssh/config

    ```shell
    Host tizen review.tizen.org
    Hostname review.tizen.org
    IdentityFile ~/.ssh/id_rsa
    User Tizen_Account_ID #update this user information what already registered ID from Tizen official website!!!
    Port 29418
    # Add the line below when using proxy, otherwise, skip it.
    # ProxyCommand nc -X5 -x <Proxy Address>:<Port> %h %p
    ```


3. Configuring Git for Gerrit Access

    * Update git information at docker/tizen-env/Dockerfile

    ```shell
    docker/tizen-env/Dockerfile

    git config --global user.name "ID" #fill ID
    git config --global user.email "E-MAIL" #fill E-MAIL
    ```

4. Run docker-compose.yml

    * How to build only Tizen Environment

    ```sh
    $ cd compose/dev_env_service/tizen-env
    $ docker-compose up -d
    ```

    * How to build full service (require setting [devspoon-web], [devspoon-startup-web])
    
    ```sh
    $ cd compose/master_service
    $ docker-compose up -d
    ```

5. A user selection
   
    * If user want to download some package or use existing project, doesn't need this step. this job require huge local size over the hundreds GB
    * It try to get all tizen repository package in a user's local
    * A user can run "repo init" using shell script at /root/repo-script there are two kind of shell script files for all case or raspberry pi 3
        * This step will require the local repository size over the hundreds GB
    
6. Test sample project

    * There are two number of projects for anchor5 and raspberry pi 3 at /root/samples
    * It try to build with "peripheral-io" package assume user updated this package's code
      * The result will be "tizen-unified_iot-headed-3parts-armv7l-artik530.tar.gz" at /Tizen-Work/mic-output 

## Additional development item

* System integration between jenkins, gitolite, tizen-env.
* Development tizen image management solution.
  * The tizen image management solution UI sample design
  ![Tizen image mng server]

## Community

* **Personal Website :** Owner's personam website is [devspoon.com]
* **Github.io :** Ther are more detail guide [devspoon.github.io]

## Demos

* **[youtube]** - Preparing
* **[inflearn]** - Demos for Devspoon features and how to use the devspoon's open-source

## Partners and Users

* Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com  
Personal github.io : [bluebamus.github.io]

* 임도현 Owner 개발자/기획자, bluebamus@gmail.com  
개인 github.io 사이트 : [bluebamus.github.io]

* Lim Tae-youn Member, Tizen Designer  
* Kang Dong-hoon Member, Tizen Developer


### How to contributing our project

* devspoon-startup-tizen code is hosted and maintained using [GitHub](https://github.com/ainpeople/devspoon-startup-tizen). 
We plan to contribute to third-party tools in the Tizen official repository(https://review.tizen.org/git/).
* To contribute to devspoon-startup-tizen, please refer to [GitHub](https://github.com/ainpeople/devspoon-startup-tizen). It
should includes most of the things you'll need to get your contribution started!


<!-- Markdown link & img dfn's -->
[Tizen ssh key 등록 저장소]: https://review.tizen.org/gerrit
[ssh-config]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/ssh_config.png
[tizen-register-site]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/tizen_ssh_register.png
[ssh-config]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/ssh_config.png
[ssh-success-msg]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/ssh_result.png
[Tizen 수동 환경 설치 & 추가 정보 제공]: https://github.com/ainpeople/ainpeople_doc
[Tizen 수동 환경 설치]: https://source.tizen.org/ko/documentation/developer-guide/getting-started-guide
[Tizen image mng server]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/sample_tizen.PNG
[devspoon-startup-tizen Build]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/AinCI-Tizen_build.jpg
[Tizen jenkins 기반 설치 공식 메뉴얼]: https://source.tizen.org/ko/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework
[Tizen documentation]: https://source.tizen.org/documentation
[Tizen 공식 사이트]: https://www.tizen.org/ko?langswitch=ko
[docker-install]: https://hcnam.tistory.com/25 
[devspoon-web]: https://github.com/devspoons/devspoon-web
[devspoon-startup-web]: https://github.com/devspoons/devspoon-startup-web
[OpenProject(KR)]: http://wiki.webnori.com/display/pms/Open+Project+7
[Jenkins(KR)]: https://jjeongil.tistory.com/810
[Harbor(KR)]: https://engineering.linecorp.com/ko/blog/harbor-for-private-docker-registry/
[mailgun]: https://www.mailgun.com/
[sendgrid]: https://sendgrid.com/
[OpenProject]: https://docs.openproject.org/user-guide/wiki/
[Jenkins]: https://en.wikipedia.org/wiki/Jenkins_(software)
[Gitolite]: https://wiki.archlinux.org/index.php/Gitolite
[Harbor]: https://en.wikipedia.org/wiki/Harbor
[Tizen-Builder-Env]: https://source.tizen.org/
[tizen web-site]: https://www.tizen.org/user/register
[bluebamus.github.io]: bluebamus.github.io
[devspoons.github.io]: devspoons.github.io