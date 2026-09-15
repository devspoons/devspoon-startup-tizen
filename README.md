# devspoon-startup-tizen

devspoon-startup-tizen is an open source solution that can easily build a reliable Tizen development environment using Docker.

## based project

devspoon-startup-tizen is built on top of the open source project [devspoon-startup-web], an integrated management solution catered to startups. It provides nginx-based PHP and Python platforms to develop web and API services. It also enables installing, backing up and managing project solutions critical for startups such as OpenProject, Jenkins, Gitolite (private Git server), and Harbour (private Docker server).

## introduce "Devspoon-Projects"

- We provide an open source infrastructure integration solution that can easily service Python, Django, PHP, etc. using docker-compose. You can install the commercial-level customizable nginx service and redis at once, and install and manage more services at once. If you are interested, please visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

## Official guide document

- preparing...

## Project management solutions

- **[OpenProject]** : Open source project management software to help you work on your project efficiently

- **[Jenkins]** : As one of the CI tools, CI (Continuous Integration) refers to continuous integration, which is an automated process for developers, and new code changes are automatically built and tested regularly to notify developers to solve problems that can occur when multiple developers develop simultaneously. Software that helps secure development stability and reliability

- **[Gitolite]** : Configuration Management Tool. user can install git server software at own server

- **[Harbor]** : The Private Docker Registry Server for businesses that store and distribute Docker Images

## Features

- **Support to make configuration files for each service(conf, yml etc)** : Using shell script, you can easily make and manage the configuration files required for nginx, php, dockerfile, etc. with only the information required by the user's keyboard.

- **Efficiently dockerfile configuration for development and service operation** : The log folder is interlocked by "volumes" in docker-compose.yml so that user can can be tracked problems even when the docker container is stopped. Webroot, nginx config, etc. are frequently modified during development so these are interlocked by "volumes"

- **Provide reverse proxy function** : Through a single nginx, you can provide multiple web and app services using PHP and Python, as well as project management services at the same time. Provides a shell script to easily create proxy configuration files for integration with the web UI of other services.

- devspoon-startup-tizen can easily build the complex configuration required to develop Samsung Tizen-based IoT devices using the already verified Dockerfile and Docker-compose.

- Development automation (CI:Continuous Integration) can be configured using jenkins provided as [devspoon-startup-web], and projects can be efficiently managed with openproject.

- Gitolite is linked with openproject and jenkins, and can be used efficiently without repository public and limitations on the capacity restriction of git server and public storage.

- Using the harbor, you can build an independent docker image according to the type, version, and kernel environment type of the smart TV, IoT development board, and download and install the docker image to any new server at any time from the docker hub.

- By configuring devspoon-startup-tizen, when moving to the internal network, you can build a development environment under various conditions and manage sources and projects even when there is no Internet connection.

## Considerations

- **No DB service** : This open source does not provide DB as docker to suggest stable operation. It is recommended to install it on a real server and access it using a network, such as port 3306. We hope that this will be done for distributed services as well. We hope that this will be consider for distributed services as well.

- **Development-oriented docker service** : This open source is perfect for startups or new service development teams that require frequent modifications and testing.

- **This open-source considers generic servers that are not support AWS, GCM** : This open source is intended to be installed and operated on a server that is directly operated, and on general server hosting, and plans to integrate with cloud services such as AWS and GCM in the future

## Install & Run

### How to build web services(PHP, python[gunicorn, uwsgi])

- Refer the guide : [devspoon-web]

### How to build project management solutions(openproject, jenkins, gitolite[private git server], harbor[private docker server])

- Refer the guide : [devspoon-startup-web]

### How to build Tizen development environment

- Build GBS(Tizen Build Server) by user self : https://source.tizen.org/documentation/developer-guide/all-one-instructions/creating-tizen-images-scratch-one-page
- Interlock GBS(Tizen Build Server) with jenkins(CI) by user self : https://source.tizen.org/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework

1. Prepare ssh key

   - Register a user account at [tizen web-site].
   - A user have to make ssh key to using ssh-keygen to register on tizen development official website for accessing tizen repository.
   - Log in to Tizen Gerrit(https://review.tizen.org/gerrit) and upload the key
     - In the Gerrit(https://review.tizen.org/gerrit) Web page, get login and go click settings and add your id_rsa.pub at the menu of "SSH Public Keys".
   - 키는 호스트에만 보관합니다 — 이미지에는 키가 들어가지 않습니다(`docker/tizen-env/.ssh` 에서는 `config` · `known_hosts` 만 복사하고, 그 폴더의 `id_rsa*` · `authorized_keys` 는 gitignore). compose 가 호스트 파일 두 개를 읽기 전용으로 bind 합니다:
     - `TIZEN_SSH_KEY` → `/root/.ssh/id_rsa` : Tizen Gerrit 에 등록한 개인키
     - `TIZEN_AUTHORIZED_KEYS` → `/root/.ssh/authorized_keys` : 컨테이너 root 로 SSH 접속을 허용할 공개키 목록(한 줄에 하나, 형식은 `docker/tizen-env/.ssh/authorized_keys.example`)

   ```sh
   # 저장소 루트에서 — 단독 tizen-env. master php 조합은 D=compose/master_service (4단계)
   D=compose/dev_env_service/tizen-env
   cp "$D/.env-example" "$D/.env"      # TIZEN_SSH_KEY · TIZEN_AUTHORIZED_KEYS 를 실제 호스트 경로로 수정
   chmod 600 ~/.ssh/tizen_id_rsa ~/.ssh/tizen_authorized_keys
   ```

   - sshd `StrictModes` 가 authorized_keys 파일의 소유자·권한을 검사하므로 600 · root 소유를 권장합니다.
   - 두 변수가 비어 있으면 compose 가 기동을 거부합니다. **경로가 틀리면** Docker 가 호스트에 root 소유 빈 디렉터리를 만들고 컨테이너는 그대로 기동되어 SSH 인증만 실패합니다 — 생긴 디렉터리를 지우고 `.env` 경로를 고친 뒤 다시 기동하세요.
   - If a user wants to access the tizen container directly for development, add a new location to "volumes" in the docker-compose.yml.

2. Update Tizen ssh config file

   - docker/tizen-env/.ssh/config

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

   - Update git information at docker/tizen-env/Dockerfile

   ```shell
   docker/tizen-env/Dockerfile

   git config --global user.name "ID" #fill ID
   git config --global user.email "E-MAIL" #fill E-MAIL
   ```

4. Run Docker Compose

   - Requirements: Docker Engine with the Compose plugin (`docker compose`). Legacy `docker-compose` (v1) 명령은 쓰지 않습니다.
   - How to build only Tizen Environment — 1단계의 `.env` 뒤, 저장소 루트에서 이동해 기동합니다(`--build` 는 업그레이드나 Dockerfile 변경 뒤 이미지를 다시 빌드합니다).

   ```sh
   cd compose/dev_env_service/tizen-env
   docker compose up -d --build
   ssh -p 2221 root@127.0.0.1    # SSH 는 기본 127.0.0.1:2221 에만 바인드 — 원격 허용은 .env 의 TIZEN_SSH_BIND=0.0.0.0
   ```

   - How to build full service (require setting [devspoon-web], [devspoon-startup-web]) — tizenenv 는 `docker-compose-php.yml` 에만 있습니다. 단독 tizen-env 와 컨테이너 이름(`tizenenv`)·포트(2221)가 같으므로 둘 중 하나만 기동합니다. gitolite 관리자 공개키·openproject/jenkins proxy 샘플 복사는 [devspoon-startup-web] 가이드의 master_service 절을 먼저 따릅니다.

   ```sh
   # 저장소 루트에서
   D=compose/master_service
   cp "$D/.env-example" "$D/.env"    # TIZEN_* 경로, OPENPROJECT_HOST_NAME · SMTP_* 자리표시자는 직접 입력
   bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
   cd "$D"
   docker compose -f docker-compose-php.yml up -d --build                    # php + openproject · jenkins · gitolite · tizenenv
   docker compose -f docker-compose-php.yml --profile redis up -d --build    # + redis
   docker compose -f docker-compose-php.yml --profile redis stop             # 프로필 없는 stop 은 redis 컨테이너를 남깁니다
   ```

   php 조합의 프로필은 `redis` 뿐입니다(celery 없음).

   > ⚠️ **pgdata 는 비워 두세요**: `compose/master_service/pgdata/` 는 저장소에 없고 첫 기동 시 Docker 가 만든 뒤 openproject 내장 PostgreSQL 이 초기화합니다. 폴더에 파일이 하나라도 있으면(`.gitkeep` 같은 점 파일 포함) `initdb` 가 `directory ... exists but is not empty` 로 실패해 컨테이너가 재시작을 반복합니다(nginx 502) — 파일을 넣지 마세요. 이미지가 `openproject/openproject:17`(내장 PostgreSQL 17)이라 이전 버전으로 만든 `pgdata/` 는 그대로 기동할 수 없습니다 — 먼저 백업하고 [OpenProject 공식 문서][OpenProject docs]의 업그레이드 절차를 따르세요.
   > 생성된 데이터는 컨테이너 postgres 사용자 소유(권한 700)라 호스트 계정으로 읽기·삭제할 수 없습니다. 백업·삭제는 서비스를 멈춘 뒤 컨테이너로 합니다. 백업 예(저장소 루트에서, 결과는 저장소 밖 `$HOME` 에 본인 소유 600 으로 저장 — DB 에 비밀번호 해시가 들어 있음):
   >
   > ```bash
   > D=compose/master_service
   > (cd "$D" && docker compose -f docker-compose-php.yml stop openproject)
   > if [ -d "$D/pgdata" ]; then
   >   docker run --rm --mount type=bind,src="$PWD/$D/pgdata",dst=/d,readonly -v "$HOME":/b alpine \
   >     sh -c "test -f /d/PG_VERSION || { echo 'PG_VERSION 없음 — 백업하지 않음' >&2; exit 1; }; test ! -f /d/postmaster.pid || { echo 'postmaster.pid 있음 — openproject 실행 중(또는 비정상 종료), 백업하지 않음' >&2; exit 1; }; umask 077; tar czf /b/openproject-pgdata.tgz.partial -C /d . && chown $(id -u):$(id -g) /b/openproject-pgdata.tgz.partial && chmod 600 /b/openproject-pgdata.tgz.partial && mv /b/openproject-pgdata.tgz.partial /b/openproject-pgdata.tgz || { rm -f /b/openproject-pgdata.tgz.partial; exit 1; }"
   > elif [ -d "$D" ]; then
   >   echo "$PWD/$D/pgdata 없음 — 첫 기동 전이면 백업할 데이터가 없습니다"
   > else
   >   echo "$PWD/$D 없음 — 저장소 루트에서 실행하세요"
   > fi
   > ```
   >
   > `stop` 줄이 오류 없이 끝났는지 먼저 확인하세요(`.env` 가 없거나 `-f` 를 빠뜨리면 실패합니다). 확인을 놓쳐도 컨테이너가 `postmaster.pid`(PostgreSQL 실행 중 표식, 정상 종료 시 삭제)가 남아 있으면 백업을 거부합니다. 없는 경로를 bind 하면 Docker Desktop 등 일부 엔진은 `--mount` 여도 빈 폴더를 만들고 빈 아카이브가 성공한 것처럼 보입니다. 그래서 호스트에서 `pgdata` 폴더를 먼저 확인하고, 컨테이너 안에서 `PG_VERSION`(PostgreSQL 클러스터 표식)이 있을 때만 아카이브를 만듭니다. 아카이브는 `.partial` 에 쓴 뒤 성공했을 때만 기존 백업과 교체합니다. 삭제는 `tar tzf ~/openproject-pgdata.tgz` 로 내용을 확인한 뒤에만 하세요. 백업만 할 때는 `(cd "$D" && docker compose -f docker-compose-php.yml start openproject)` 로 다시 기동합니다.

5. A user selection

   - If user want to download some package or use existing project, doesn't need this step. this job require huge local size over the hundreds GB
   - It try to get all tizen repository package in a user's local
   - A user can run "repo init" using shell script at /root/repo-script there are two kind of shell script files for all case or raspberry pi 3
     - This step will require the local repository size over the hundreds GB

6. Test sample project

   - There are two number of projects for anchor5 and raspberry pi 3 at /root/samples
   - It try to build with "peripheral-io" package assume user updated this package's code
     - The result will be "tizen-unified_iot-headed-3parts-armv7l-artik530.tar.gz" at /Tizen-Work/mic-output

## Additional development item

- System integration between jenkins, gitolite, tizen-env.
- Development tizen image management solution.
  - The tizen image management solution UI sample design
    ![Tizen image mng server]

## Community

- **Personal Website** : Owner's personal website is [devspoon.com](devspoon.com)

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com
  Personal site : [devspoon.com](devspoon.com)

- Lim Tae-youn Member, Tizen Designer
- Kang Dong-hoon Member, Tizen Developer

### How to contributing our project

- devspoon-startup-tizen code is hosted and maintained using [GitHub](https://github.com/ainpeople/devspoon-startup-tizen).
  We plan to contribute to third-party tools in the Tizen official repository(https://review.tizen.org/git/).
- To contribute to devspoon-startup-tizen, please refer to [GitHub](https://github.com/ainpeople/devspoon-startup-tizen). It
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
[OpenProject docs]: https://docs.openproject.org/installation-and-operations/
[Jenkins]: https://en.wikipedia.org/wiki/Jenkins_(software)
[Gitolite]: https://wiki.archlinux.org/index.php/Gitolite
[Harbor]: https://en.wikipedia.org/wiki/Harbor
[Tizen-Builder-Env]: https://source.tizen.org/
[tizen web-site]: https://www.tizen.org/user/register
[bluebamus.github.io]: bluebamus.github.io
[devspoons.github.io]: devspoons.github.io
