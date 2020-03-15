# devspoon-startup-tizen

## What is devspoon-startup-tizen?

devspoon-startup-tizen creates Build, Test, and CI servers with Docker to automatically generate system images for porting to Tizen-based IoT devices. This provides a development server infrastructure for Tizen-based IoT devices.

## 내부 구성 요소

### 통합된 솔루션

* nginx/php7.3 가상 호스팅, proxy 솔루션  
  * Tizen 포팅 이미지 관리 솔루션 지원
* OpenProject 프로젝트 관리 솔루션
* Jenkins CI 솔루션
* Tizen 빌드 솔루션

### 통합 예정 솔루션

* git server
* docker-image server
* AWS, GCP 기반 Docker / Docker-compose 
* DB는 데이터의 안정성을 위해 Docker로 제공하지 않으며 따로 설치하여 사용 하기를 권장함
* Tizen 이미지 관리 솔루션은 3306 포트가 local과 포트포워딩 되어 있으므로 이를 통해 외부 서버와 연동 가능함

### 서비스 특징

* [OpenProject] : 프로젝트 관리 프로세스(PMI)를 지원 하는 오픈 소스 프로젝트 관리 소프트웨어
* [Jenkins] : CI 툴 중 하나로 CI (Continuous Integration)는 개발자가 공유 버전 제어 저장소에서 팀의 코드를 컴파일 할 수 있도록함으로써 빌드주기 비 효율성을 줄이기 위한 프로세스
* [devspoon-web-php] 기반의 가상 호스팅, OpenProject, Jenkins를 개별 서버로 사용할 수 있고 단일 nginx에 통합하여 사용할 수 있음 예) test.com 도메인을 통해 a.test.com/ b.test/com 으로 가상 호스팅을 운영하고 
  * open.test.com으로 오픈프로젝트를 운영
  * jen.test.com으로 jenkins를 운영할 수 있음
* [Tizen-Builder-Env] : Tizen IoT 제품을 만들기 위한 개발 환경 구축
* 상위 솔루션은 compose/full_service 안의 docker-compose.yml 파일을 실행하여 하나의 nginx 컨테이너로 각각 다른 도메인 서비스를 연결할 수 있음

### 각 서비스별 사용 방법

* 가상 호스팅 사용 방법 : [devspoon-web-php]
* OpenProject, Jenkins 사용 방법 : [devspoon-startup-web-php]
* GBS(Tizen Build Server) 구축 방법 : https://source.tizen.org/documentation/developer-guide/all-one-instructions/creating-tizen-images-scratch-one-page
* GBS(Tizen Build Server)와 Jenkins(CI) 연동 방법 : https://source.tizen.org/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework

### How to build a Tizen image without using devspoon-startup-tizen(기존 방법)
https://github.com/ainpeople/ainpeople_doc/blob/master/README.md

### Third-party Development Infrastructure
![devspoon-startup-tizen Build]

## Getting started

### Dependencies

The following packages are required(Ubuntu 18.04 LTS):

* docker-ce
* docker-ce-cli
* containerd.io
* vim

### Download devspoon-startup-tizen from GitHub

devspoon-startup-tizen is built with [Docker](https://www.docker.com/), an open-source container tool
developed by Docker Inc. We suggest downloading and installing Docker using the
[official instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/) for Ubuntu.

```shell
$ sudo apt-get update
$ sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
$ sudo apt-key fingerprint 0EBFCD88
$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli containerd.io
```

The minimum required Docker version is 19.03.5

* Clone the code from the devspoon-startup-tizen GitHub repository and go to devspoon-startup-tizen home folder
```bash
$ git clone https://github.com/ainpeople/devspoon-startup-tizen.git
$ cd devspoon-startup-tizen
```

### Tizen Gerrit 사이트 접속을 위한 SSH 설정하기

Build Server에서 사용하기 위해서 사전에 진행해야 함

1. Generate RSA keys

```shell
$ cd <devspoon-startup-tizen home folder>/docker/tizen-env/.ssh
$ ssh-keygen [-t rsa] [-b 4096 ] [-C "<Comments>"]
```

2. config 파일 생성

>User <Tizen_Gerrit_Site_Username>에 타이젠 공식 사이트(http://review.tizen.org/)에 가입된 계정 정보를 입력(사전에 Tizen Gerrit 가입이 필요함)

```shell
$ cd <devspoon-startup-tizen home folder>/docker/tizen-env/.ssh
$ vi config

Host tizen review.tizen.org
Hostname review.tizen.org
IdentityFile ~/.ssh/id_rsa
User <Tizen_Gerrit_Site_Username>
Port 29418
# Add the line below when using proxy, otherwise, skip it.
# ProxyCommand nc -X5 -x <Proxy Address>:<Port> %h %p
```

>Note:
Both "tizen" and "review.tizen.org" are aliases of the hostname. "tizen" is configured for simplicity of commands when initializing git repositories and cloning specific Tizen projects, and "review.tizen.org" is configured to work with the manifest.xml and _remote.xml files when synchronizing the entire Tizen source.
>
>The ~/.ssh/config file must not be written in by other users. Make sure to remove the write permission by executing chmod o-w ~/.ssh/config. For more information on ssh_config, see man ssh_config.

* Config 파일 예시
  
![ssh-config]

3. Copy the full text in devspoon-startup-tizen home folder/docker/tizen-env/.ssh/id_rsa.pub

```shell
$ vi <devspoon-startup-tizen home folder>/docker/tizen-env/.ssh/id_rsa.pub
```

4. Log in to Tizen Gerrit(https://review.tizen.org/gerrit) and upload the key(사전에 Tizen Gerrit 가입이 필요함)
* In the Gerrit(https://review.tizen.org/gerrit) Web page, click the user name on the top right corner (with an inverted triangle on the right), and select Settings to display the Settings Web page.
* Click SSH Public Keys in the left panel, paste the text copied earlier into the Add SSH Public Key box, and click Add.

5. Verify the SSH connection(단, Docker-compose로 컨테이너 구동 후 Tizen Build Server 컨테이너에 접속하여 실행할 것)

```shell
$ ssh tizen

**** Welcome to Gerrit Code Review ****
```

* SSH connection 확인 예시  

![ssh-success-msg]

6. Configuring Git for Gerrit Access

* devspoon-startup-tizen home folder/docker/tizen-env/Dockerfile의 다음 항목을 변경
  * 항목 중 First_Name Last_Name 부분과 E-mail_Address 부분을 변경해줘야 함
known_hosts 파일 그대로 유지

```shell
$ vi <devspoon-startup-tizen home folder>/docker/tizen-env/Dockerfile

git config --global user.name <First_Name Last_Name>
git config --global user.email "<E-mail_Address>"
```

### Start devspoon-startup-tizen on local machine(Docker-compose 실행)

To run devspoon-startup-tizen locally on the development machine, simply run the following command:

* Docker-compose로 Tizen 환경만 구축하는 방법(Case 1)

```sh
$ cd <devspoon-startup-tizen home folder>\compose\tizen-jenkins
$ docker-compose up -d 실행
```

* Docker-compose로 통합 환경 전체를 구축하는 방법(Case 2)

```sh
$ cd <devspoon-startup-tizen home folder>\compose\full_service
$ docker-compose up -d 실행
```

### Docker 명령어(참고사항)

* 실행된 Docker 컨테이너에 접속하는 방법

```sh
$ docker exec -it tizenenv bash
```

* Docker 이미지를 다시 빌드 하는 경우(전체 컨테이너 및 이미지 삭제)

```sh
$ docker stop $(docker ps -a -q)
$ docker rm $(docker ps -a -q)
$ docker rmi $(docker images -a -q)
$ docker prune network
```

### Interacting with Build Artifacts Management System Web UI(추가 예정[현재 미구현])

* To access devspoon-startup-tizen(Build Artifacts Management System) Web UI, use a browser to open
  * http://localhost 로 접속, 다음 예시와 같이 build artifacts들을 관리할 수 있음

* Web UI 예시
  * 해당 솔루션은 차후 추가될 예정

![Tizen image mng server]

## 현재 업데이트 내역 및 추가 개발 목록

### 업데이트 내역

* 0.0.1
  * GBS(Build Server) 컨테이너에 Tizen 빌드 툴(Repo, GBS, MIC 등) 설치 및 환경 설정 완료
  * Jenkins 컨테이너에 기본 세팅 완료

### 추가 개발 목록

* Tizen 빌드 및 이미지 생성하는 수동 빌드 과정 테스트 -2월 중
* jenkins master / slave 구축 및 빌드 연동 -2월 중
* git server / github와 jenkins와 연동하여 빌드 연동 -2월 중

### Third-party Development Infrastructure 업데이트 계획

* git-server, docker-image 컨테이너 
* Docker 통합 모니터링 솔루션
* 독립서버, AWS, GCP 기반에 대한 각각의 쿠버네티스 기능을 docker-compose로 개별 관리

## Contribution

### 주요 멤버

* 임도현 Owner, Tizen Specialist(심사중), bluebamus@gmail.com
* 임태연 Member, Tizen Developer
* 강동훈 Member, Tizen Developer

### How to contributing our project

* devspoon-startup-tizen code is hosted and maintained using [GitHub](https://github.com/ainpeople/devspoon-startup-tizen). 
We plan to contribute to third-party tools in the Tizen official repository(https://review.tizen.org/git/).
* To contribute to devspoon-startup-tizen, please refer to [GitHub](https://github.com/ainpeople/devspoon-startup-tizen). It
should includes most of the things you'll need to get your contribution started!


<!-- Markdown link & img dfn's -->
[Tizen ssh key 등록 저장소]: https://review.tizen.org/gerrit
[ssh-config]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/ssh_config.png
[tizen-register-site]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/tizen_ssh_register.png
[ssh-config]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/ssh_config.png
[ssh-success-msg]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/ssh_result.png
[Tizen 수동 환경 설치 & 추가 정보 제공]: https://github.com/ainpeople/ainpeople_doc
[Tizen 수동 환경 설치]: https://source.tizen.org/ko/documentation/developer-guide/getting-started-guide
[Tizen image mng server]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/sample_tizen.PNG
[devspoon-startup-tizen Build]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/devspoon-startup-tizen_build.jpg
[Tizen jenkins 기반 설치 공식 메뉴얼]: https://source.tizen.org/ko/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework
[Tizen documentation]: https://source.tizen.org/documentation
[Tizen 공식 사이트]: https://www.tizen.org/ko?langswitch=ko
[docker-install]: https://hcnam.tistory.com/25 
[devspoon-web-php]: https://github.com/devspoons/devspoon-web-php
[devspoon-startup-web-php]: https://github.com/devspoons/devspoon-startup-web-php
[OpenProject]: http://wiki.webnori.com/display/pms/Open+Project+7
[Jenkins]: https://jjeongil.tistory.com/810
[Tizen-Builder-Env]: https://source.tizen.org/
