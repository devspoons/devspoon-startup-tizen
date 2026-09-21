# devspoon-startup-tizen

devspoon-startup-tizen is an open source solution that can easily build a reliable Tizen development environment using Docker.

## based project

devspoon-startup-tizen is built on top of the open source project [devspoon-startup-web], an integrated management solution catered to startups. It provides nginx-based PHP and Python platforms to develop web and API services. It also enables installing, backing up and managing project solutions critical for startups such as Plane, Jenkins, Gitea (private Git server), and Harbor (private Docker server).

## introduce "Devspoon-Projects"

- We provide an open source infrastructure integration solution that can easily service Python, Django, PHP, etc. using docker-compose. You can install the commercial-level customizable nginx service and redis at once, and install and manage more services at once. If you are interested, please visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

## Official guide document

- preparing...

## Project management solutions

- **[Plane]** : Open source project management software (issues · cycles · modules) to help you work on your project efficiently ([self-hosting 문서][Plane docs])

- **[Jenkins]** : As one of the CI tools, CI (Continuous Integration) refers to continuous integration, which is an automated process for developers, and new code changes are automatically built and tested regularly to notify developers to solve problems that can occur when multiple developers develop simultaneously. Software that helps secure development stability and reliability

- **[Gitea]** : Lightweight self-hosted git service — web UI, issues, pull requests, and git over SSH/HTTP ([docker 설치 문서][Gitea docs])

- **[Harbor]** : The Private Docker Registry Server for businesses that store and distribute Docker Images

## Features

- **Support to make configuration files for each service(conf, yml etc)** : Using shell script, you can easily make and manage the configuration files required for nginx, php, dockerfile, etc. with only the information required by the user's keyboard.

- **Efficiently dockerfile configuration for development and service operation** : The log folder is interlocked by "volumes" in docker-compose.yml so that user can can be tracked problems even when the docker container is stopped. Webroot, nginx config, etc. are frequently modified during development so these are interlocked by "volumes"

- **Provide reverse proxy function** : Through a single nginx, you can provide multiple web and app services using PHP and Python, as well as project management services at the same time. Provides a shell script to easily create proxy configuration files for integration with the web UI of other services.

- devspoon-startup-tizen can easily build the complex configuration required to develop Samsung Tizen-based IoT devices using the already verified Dockerfile and Docker-compose.

- Development automation (CI:Continuous Integration) can be configured using jenkins provided as [devspoon-startup-web], and projects can be efficiently managed with Plane.

- Gitea is linked with Plane and jenkins, and can be used efficiently without repository public and limitations on the capacity restriction of git server and public storage.

- Using the harbor, you can build an independent docker image according to the type, version, and kernel environment type of the smart TV, IoT development board, and download and install the docker image to any new server at any time from the docker hub.

- By configuring devspoon-startup-tizen, when moving to the internal network, you can build a development environment under various conditions and manage sources and projects even when there is no Internet connection.

## Considerations

- **No DB service** : This open source does not provide DB as docker to suggest stable operation. It is recommended to install it on a real server and access it using a network, such as port 3306. We hope that this will be done for distributed services as well. We hope that this will be consider for distributed services as well.

- **Development-oriented docker service** : This open source is perfect for startups or new service development teams that require frequent modifications and testing.

- **This open-source considers generic servers that are not support AWS, GCM** : This open source is intended to be installed and operated on a server that is directly operated, and on general server hosting, and plans to integrate with cloud services such as AWS and GCM in the future

- **Docker Compose 2.20 이상 필요** : Plane · Gitea 정의를 `compose/common/{plane-services,gitea-service}.yml` 한 곳에 두고 master_service 5조합과 단독 스택이 `include:` 로 참조합니다. 2.20 미만에서는 `include:` 를 인식하지 못해 `docker compose config` 부터 실패합니다.

- **git over SSH 는 호스트 2222** : Gitea 컨테이너가 호스트 `2222`(`GITEA_SSH_PORT`)를 직접 게시합니다. 클라우드라면 방화벽·보안 그룹(예: OCI VCN 보안 목록)에도 인바운드 2222 를 열어야 외부에서 SSH clone 이 됩니다 — 호스트 방화벽만 열면 Docker 가 게시한 포트는 그대로 막혀 있습니다. 단독 tizen-env 는 2221 을 쓰므로 둘은 겹치지 않습니다.

- **Tizen 환경 제약 (잔여 위험)** :
  - tizen-env 이미지는 빌드 검증을 하지 않았습니다. 베이스 이미지가 `ubuntu:18.04` 입니다(Tizen 도구 apt 소스가 Ubuntu 18.04 전용 — `docker/tizen-env/Dockerfile`). CI(`script/ci/repo-steps.sh`)는 tizen-env 를 빌드·기동하지 않고 compose 렌더·SSH 포트·키 fail-fast·sshd 설정만 정적으로 검사합니다.
  - tizen-env · tizenenv 는 `privileged: true` 입니다 — Tizen mic 이미지 생성의 loop mount 용으로 빌드 검증 전까지 유지합니다(대체 후보 `cap_add: [SYS_ADMIN]` + `devices: [/dev/loop-control]`). 컨테이너가 호스트 장치에 접근할 수 있으므로 신뢰하는 호스트에서만 기동하세요.
  - master_service 의 `docker-compose-php.yml` 은 tizenenv 를 항상 포함하므로 Tizen 을 쓰지 않아도 `.env` 에 `TIZEN_SSH_KEY` · `TIZEN_AUTHORIZED_KEYS` 가 있어야 합니다(비어 있으면 `docker compose` 가 거부). 다른 master 조합(gunicorn · uvicorn · uwsgi · daphne)에는 tizenenv 가 없습니다.
  - 단독 tizen-env 와 master php 조합의 tizenenv 는 컨테이너 이름(`tizenenv`)·포트(2221)가 같아 동시에 기동할 수 없습니다.

## Install & Run

### Web stack & CI

웹 스택 서술은 정본 [devspoon-web] README 와 같습니다(검수 완료본을 이 저장소 구조에 맞춤). 모든 명령은 저장소 루트 기준입니다.

#### 스택 5종

| 스택 | compose 폴더 | app 서비스 | nginx 설정 폴더 | 프로파일 | 호스트 포트 |
|---|---|---|---|---|---|
| gunicorn | `compose/web_service/nginx_gunicorn` | `gunicorn-app` | `config/web-server/nginx/gunicorn` | `celery` | 80, 443, `127.0.0.1:5555`(flower) |
| uvicorn | `compose/web_service/nginx_uvicorn` | `uvicorn-app` | `config/web-server/nginx/uvicorn` | `celery` | 80, 443, `127.0.0.1:5555` |
| uwsgi | `compose/web_service/nginx_uwsgi` | `uwsgi-app` | `config/web-server/nginx/uwsgi` | `celery` | 80, 443, `127.0.0.1:5555` |
| daphne | `compose/web_service/nginx_daphne` | `daphne-app` | `config/web-server/nginx/gunicorn` (공유) | `celery` | 80, 443, `127.0.0.1:5555` |
| php 8.4 | `compose/web_service/nginx_php` | `php-app` | `config/web-server/nginx/php` | `redis` | 80, 443 |

- Python 스택은 `webserver`·app·`redis` 가 항상 뜨고, `--profile celery` 가 `celery`·`celery-beat`·`flower` 를 더합니다. php 스택은 `webserver`·`php-app` 이 뜨고 `--profile redis` 가 `redis` 를 더합니다.
- 모든 스택이 80/443 을 쓰므로 한 호스트에서 한 스택만 기동합니다.
- 샘플 앱: Python 스택은 `www/django_sample`, php 스택은 `www/php_sample`.

#### 1. `.env` 비밀값 생성 (최초 설정 · 업그레이드)

`.env-example` 의 비밀값(Python 스택 `DJANGO_SECRET_KEY` · `REDIS_PASSWORD` · `FLOWER_PWD`, php 스택 `REDIS_PASSWORD`)은 **빈 값**입니다. compose 가 `${VAR:?}` 로 요구하므로 비워 둔 채로는 기동이 거부됩니다. 저장소 루트에서 스택마다 한 번:

```bash
D=compose/web_service/nginx_gunicorn
cp "$D/.env-example" "$D/.env"
bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
```

- 값이 비었거나 옛 `CHANGE_ME_*` 인 비밀 키만 `openssl rand -hex` 무작위 값으로 채웁니다(`DJANGO_SECRET_KEY` 100 hex, `*_KEY_BASE` 128 hex, 그 외 64 hex). 이미 값이 있는 키는 바꾸지 않습니다.
- 같은 폴더의 임시 파일에 쓴 뒤 교체하며, 값을 생성했으면 권한을 600 으로 좁힙니다(더 엄격하면 유지). openssl 이 없거나 실패하면 `FAIL` 로 끝나고 `.env` 내용은 바뀌지 않습니다.
- **비밀이 아닌 자리표시자는 헬퍼가 채우지 않습니다 — 운영 전에 직접 입력하세요**: `FLOWER_ID`(`CHANGE_ME_FLOWER_USER`), master·단독 plane 의 `PLANE_DOMAIN`·`PLANE_WEB_URL`·`PLANE_CORS_ALLOWED_ORIGINS`(proxy conf 의 `server_name` 과 동일), gitea 의 `GITEA_DOMAIN`·`GITEA_ROOT_URL`, `DJANGO_ALLOWED_HOSTS`(도메인 추가).
- 호스트에서 `manage.py` 를 직접 실행할 때만 `www/django_sample` 의 `secrets.json` 이 필요합니다: `bash -c '. script/lib/django_secrets.sh && ensure_django_secrets'` (없을 때만 생성, 600). 컨테이너는 `DJANGO_SECRET_KEY` 환경변수를 씁니다.

> **업그레이드 노트 — 이전 버전에서 쓰던 `.env` 를 유지하는 경우**: 옛 `.env` 에는 `DJANGO_SECRET_KEY` 줄이 없거나 `CHANGE_ME_*` 값이 남아 있을 수 있습니다. 위 헬퍼를 같은 `.env` 에 한 번 실행하면 같은 폴더 `docker-compose*.yml` 과 그 파일들이 `include:` 로 참조하는 조각(`compose/common/*.yml`)이 `:?` 로 요구하는 비밀 키(이름에 SECRET·PASSWORD·PWD 포함 또는 `_KEY_BASE` 로 끝남) 중 없는 키를 끝에 추가하고 `CHANGE_ME_*` 를 교체하며, 기존 값은 보존하고 권한을 600 으로 맞춥니다. `KEY=""` 처럼 따옴표로 둘러싼 빈 값은 채우지 않으니 먼저 `KEY=` 로 고치세요.
>
> 이전 버전은 `compose/web_service/*`·`compose/master_service`·`compose/project_mng_service/*`·`compose/dev_env_service/tizen-env` 의 `.env` 를 git 으로 추적했습니다. 이 버전에서 추적이 해제되어 `git pull` 이 로컬 `.env` 를 지울 수 있으니 **pull 전에 `.env` 를 다른 곳에 복사**해 두세요. 이전에 저장소에 공개됐던 `secrets.json`·`.env` 의 키로 운영 중이라면 새 값으로 교체하세요(세션 무효화).

#### 2. 기동

1절의 `.env` 명령(저장소 루트) 뒤, 저장소 루트에서 스택 폴더로 이동해 기동합니다(`--build` 는 업그레이드나 Dockerfile / `uv.lock` 변경 뒤 이미지를 다시 빌드합니다). 한 호스트에 한 스택만 띄웁니다.

```bash
# gunicorn (저장소 루트에서)
cd compose/web_service/nginx_gunicorn
docker compose up -d --build             # webserver + gunicorn-app + redis
docker compose --profile celery up -d    # + celery · celery-beat · flower
```

uvicorn · uwsgi · daphne 는 gunicorn 과 같은 명령이며 폴더 이름만 `compose/web_service/nginx_uvicorn` · `nginx_uwsgi` · `nginx_daphne` 로 바꿉니다.

```bash
# php (저장소 루트에서)
cd compose/web_service/nginx_php
docker compose up -d --build             # webserver + php-app
docker compose --profile redis up -d     # + redis
```

- **기동 순서 — app 이 DB 를 초기화한 뒤 celery · beat**: 각 스택의 app 서비스만 서버 기동 전에 `uv sync` 후 DB 를 1회 초기화합니다(`manage.py` 가 있으면 `python manage.py migrate --noinput`, 없으면 프로젝트의 `prestart.sh`). `celery` · `celery-beat` 는 `depends_on: <app>: condition: service_healthy` 라 app 이 healthy 가 된 뒤 기동합니다 — 동시 migrate 경쟁이 없습니다.
- **Flower** 는 **`127.0.0.1:5555` 에만 바인드**됩니다. 원격 접근은 SSH 터널: `ssh -L 5555:127.0.0.1:5555 <host>` 후 로컬 브라우저에서 `http://127.0.0.1:5555`.
- `DJANGO_DEBUG`(기본 `0`) · `DJANGO_ALLOWED_HOSTS` 를 `.env` 로 제어하며 app · celery · beat 에 전달됩니다. `DJANGO_DEBUG=1` 은 로컬 개발에서만 쓰세요.
- 컨테이너는 `docker compose stop` / `start` / `restart` 로 운영합니다. 프로필 서비스까지 대상이면 기동과 같은 프로필을 붙입니다(`docker compose --profile celery stop`, php 는 `--profile redis stop`) — 프로필 없는 `stop` 은 celery · celery-beat · flower(php 는 redis) 컨테이너를 남깁니다.

#### 3. SQLite 데이터 위치 — named volume `/data`

Python 스택(gunicorn · uvicorn · uwsgi · daphne)의 SQLite 는 호스트 `www/<PROJECT_DIR>/db.sqlite3` 가 아니라 compose named volume `app-data` 의 **`/data/<PROJECT_DIR>.sqlite3`** (`SQLITE_PATH` 환경변수)에 저장됩니다. 컨테이너는 이 볼륨과 로그 디렉터리만 www-data 소유로 맞추고, 호스트 소스 트리(`/www`)의 소유권은 바꾸지 않습니다. `SQLITE_PATH` 가 없는 호스트 `manage.py` 실행은 여전히 `www/<PROJECT_DIR>/db.sqlite3` 를 씁니다.

**기존 DB 이관** (호스트 `db.sqlite3` 를 계속 쓰려면 — gunicorn 스택 예, celery 프로파일은 이관 후 기동):

```bash
cd compose/web_service/nginx_gunicorn
docker compose up -d --build  # app-data 볼륨 생성 (빈 DB 로 migrate 됨)
docker compose cp ../../../www/django_sample/db.sqlite3 gunicorn-app:/data/django_sample.sqlite3
docker compose exec gunicorn-app chown www-data:www-data /data/django_sample.sqlite3
docker compose restart gunicorn-app   # 기동 명령이 다시 돌며 이관한 DB 에 미적용 migrate 반영 (app 만 — 전체 restart 는 nginx 기동 경합)
```

> ⚠️ **`docker compose down -v` 는 `app-data` 볼륨, 즉 SQLite DB 를 삭제합니다.** 컨테이너만 내리려면 `docker compose stop` 을 쓰세요 (`down` 은 비권장, 특히 `-v`; 프로필 서비스는 2절처럼 `--profile` 을 붙임). 백업: `docker compose cp gunicorn-app:/data/django_sample.sqlite3 ./backup.sqlite3`. master_service 의 Plane 데이터 볼륨(`plane-pgdata`·`plane-uploads` 등)과 Gitea 저장소 볼륨(`gitea-data`)도 `-v` 로 삭제됩니다.

#### 4. 이미지 이름 · 빌드 · uv

- 이미지 이름은 `${IMAGE_NAMESPACE:-devspoon}-nginx:latest` 형식입니다(`-py-app:latest`, `-uwsgi-app:latest`, `-php-app:8.4`). 기본값이면 `devspoon-*` 태그이고, 검증기·`verify-ngxblocker.sh` 는 `IMAGE_NAMESPACE=devspoon-it`, run-ci 빌드 단계(`s2_build.sh`)는 `devspoon-test/*` 태그로 빌드해 운영 태그를 덮어쓰지 않습니다.
- 앱 이미지(`py-app` · `uwsgi-app`)의 사전 설치 패키지는 `www/django_sample/uv.lock` 에서 도출됩니다. compose 는 `build.additional_contexts: lock: ../../../www/django_sample` 로 이를 자동 전달하므로 **Docker Compose ≥ 2.17** 이 필요합니다 (`docker compose version`).
- Compose 가 2.17 미만이거나 `docker build` 를 직접 쓸 때는 추가 빌드 컨텍스트를 명시합니다(저장소 루트, BuildKit):

  ```bash
  docker build --build-context lock=www/django_sample -t devspoon-py-app:latest docker/gunicorn/
  docker build --build-context lock=www/django_sample -t devspoon-uwsgi-app:latest docker/uwsgi/
  ```

  빠뜨리면 빌드가 `"/pyproject.toml": not found` 로 실패합니다.
- **uv**: `www/django_sample` 의 의존성은 `pyproject.toml` · `uv.lock` 으로 관리합니다. 컨테이너는 가상환경 없이 시스템 Python 에 설치하며(`UV_PROJECT_ENVIRONMENT=/usr/local`), 기동 명령이 `uv sync --inexact --extra <stack> --extra celery` 를 실행합니다. 같은 스택의 app · celery · celery-beat 는 같은 extras 로 sync 합니다. 의존성 추가는 호스트에서 `cd www/django_sample && uv add <pkg>` 후 `uv.lock` 을 커밋하고 스택 폴더에서 `docker compose --profile celery stop && docker compose up -d --build` 로 재기동하고, celery 사용 시 `docker compose --profile celery up -d` 로 celery · celery-beat 도 다시 올립니다(앱 이미지 사전 설치도 `uv.lock` 에서 도출; celery 는 `build:` 없이 같은 이미지를 참조하므로 프로필 없는 `up --build` 만으로는 옛 이미지·옛 의존성으로 계속 동작).

#### 5. nginx · php 설정

- nginx conf 생성기: `config/web-server/nginx/<gunicorn|uvicorn|uwsgi|php>/` 의 `nginx_http_conf.sh` · `nginx_https_conf.sh` 가 `sample_nginx_http(s).conf` 로 `conf.d/` 에 도메인별 conf 를 만듭니다(`-h` 로 옵션 확인). daphne 는 gunicorn 폴더를 씁니다.
- nginx 기동 훅: 이미지의 `/docker-entrypoint.d/30-wait-upstreams.sh` 가 conf 의 upstream(앱 컨테이너) 이름이 해석될 때까지 최대 `NGINX_UPSTREAM_WAIT` 초(기본 30, `0` 이면 비활성, webserver `environment` 로 조정) 기다린 뒤 nginx 를 띄웁니다 — 재부팅·`start` 처럼 app 보다 webserver 가 먼저 뜰 때 `[emerg] host not found in upstream` 으로 죽는 것을 막습니다. 전체 `docker compose restart` 는 동시 재시작이라 훅으로도 완전히 막히지 않으니 conf 반영은 `nginx -s reload`, 전체 재기동은 `stop` → `start` 를 쓰세요.
- php-fpm pool 은 **`config/app-server/php/pool.d/www.conf` 를 편집**합니다. compose 는 `www.conf`(`/usr/local/etc/php-fpm.d/www.conf`)와 `config/app-server/php/php_ini/php.ini` 만 단일 파일로 읽기 전용 마운트하므로, `php_conf.sh` 가 `pool.d/` 에 만드는 `<DOMAIN>_php.conf` 는 로드되지 않습니다.

#### 6. CI — `script/ci/run-ci.sh`

`bash script/ci/run-ci.sh` 가 11단계를 순서대로 실행합니다: preflight → prereq·로그 디렉터리 → nginx conf 생성기 → compose 검증 → 저장소 고유 검사(`script/ci/repo-steps.sh`) → 이미지 빌드 → 정적 회귀(s6) → healthcheck → 스택 매트릭스(gunicorn · uvicorn · uwsgi · daphne · php 실기동) → 샘플 프로젝트 → 스크립트 로그.

- 실제 컨테이너를 띄우므로 호스트 80/443/5555 가 비어 있어야 합니다. 필요 도구: docker(Compose ≥ 2.17), uv, jq, curl, openssl, php-cli.
- GitHub Actions(`.github/workflows/test.yml`)는 같은 스크립트를 실행합니다. 알림은 선택 — 저장소 secrets `SLACK_WEBHOOK_URL`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` 가 없으면 해당 알림을 건너뜁니다. 업로드 로그(`log/ci`, `log/test_run`)는 `script/lib/mask_secrets.sh` 로 비밀값을 마스킹한 뒤 올립니다.

### How to build project management solutions(plane, jenkins, gitea[private git server], harbor[private docker server])

- Refer the guide : [devspoon-startup-web] — master_service · 단독 plane · jenkins · gitea 의 `.env` · proxy 샘플 · 관리자 계정 생성 절차는 그 가이드를 따릅니다. tizenenv 가 포함된 master php 조합 명령은 아래 Tizen 절 4단계에 있습니다.

#### 단독 서비스 동시 기동 규칙

- **단독 서비스는 한 번에 하나만 기동합니다.** `nginx_plane` · `nginx_jenkins` 는 둘 다 호스트 80/443 을, `gitea` 는 2222 를 쓰고, `plane-*` · `jenkins` · `gitea` 컨테이너 이름이 master_service 와 같습니다. 웹 스택(`compose/web_service`)·master_service 와도 동시에 띄울 수 없습니다.
- **여러 서비스를 동시에 운영하려면 master_service 를 쓰세요.**
- **단독 proxy 스택(`nginx_plane` · `nginx_jenkins` · `gitea`)은 HTTP 전용입니다(80, TLS 없음).** 443 은 매핑돼 있지만 catch-all `default.conf` 가 TLS 핸드셰이크를 거부(`ssl_reject_handshake on`)할 뿐 서비스용 TLS 서버 블록이 없어, 로그인 자격증명이 80 으로 평문 전송됩니다. 공개망 운영은 앞단 TLS 종단(별도 리버스 프록시·LB) 뒤에 두거나, TLS 를 구성할 수 있는 master_service 를 쓰세요.
- 단독 tizen-env(`compose/dev_env_service/tizen-env`)는 호스트 포트 2221 만 쓰므로 웹 스택·단독 서비스와 함께 띄울 수 있지만, tizenenv 가 들어 있는 master php 조합과는 동시에 띄울 수 없습니다.

#### Plane · Gitea 데이터 볼륨

Plane 데이터(`plane-pgdata` · `plane-uploads` · `plane-rabbitmq` · `plane-redisdata` · `plane-proxy-*` · `plane-logs-*`)와 Gitea 저장소(`gitea-data`)는 호스트 bind 가 아니라 named volume 입니다 — 호스트 폴더를 미리 만들 필요가 없고 컨테이너 uid 와 호스트 계정의 소유권이 어긋나지 않습니다. 볼륨 이름 앞에는 compose 프로젝트(폴더) 이름이 붙습니다(단독 `gitea_gitea-data`, master `master_service_gitea-data` — `docker volume ls` 로 확인).

- **`docker compose down -v` 는 이 볼륨을 전부 삭제합니다.** 컨테이너만 내릴 때는 `stop` 을 쓰세요.
- 백업·복원 절차(Plane `pg_dump` · MinIO 업로드 아카이브, Gitea `gitea dump`)는 [devspoon-startup-web] 가이드의 Plane · Gitea 절을 따릅니다.


#### Harbor 공존

- 저장소에 있던 Compose v1 설치 스크립트는 삭제됐습니다. 번들된 Harbor v2.0.0 installer(`compose/project_mng_service/harbor-v2.0.0/install.sh` · `common.sh`)는 `docker compose` 플러그인을 쓰지 않고 **`docker-compose` 라는 이름의 명령**을 직접 호출합니다. `common.sh` 의 `check_dockercompose` 가 `docker-compose --version` 출력을 **1.18.0 이상**으로 파싱하지 못하면 `[Step 1]` 에서 `Need to install docker-compose(1.18.0+) by yourself first and run this script again.` 를 출력하고 **exit 1** 로 중단하므로, 레거시(legacy) Compose v1(1.18.0+) 바이너리를 운영자가 직접 PATH 에 준비합니다. (관문은 이름이 `docker-compose` 인 명령의 출력만 봅니다 — v2 형식 문자열을 내는 같은 이름의 실행 파일도 이 관문을 통과합니다. `docker compose` 플러그인을 부르는 래퍼 `printf '#!/bin/sh\ncase "$1" in --version|version) exec docker compose version ;; esac\nexec docker compose "$@"\n' | sudo tee /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose` 로 http·https 설치와 기동(포털·API·레지스트리 토큰)을 검증했습니다 — 최근 Compose 플러그인은 `docker compose --version` 에 버전이 아니라 사용법을 출력하므로 래퍼가 `version` 으로 바꿔 전달해야 합니다.)
- `install.sh` 는 내부에서 `./prepare` 를 **직접 실행**하므로 `prepare` 한 파일만 저장소에 **실행 권한(`100755`)으로 추적**됩니다 — 별도 `chmod` 없이 그 지점을 통과합니다. 나머지 스크립트(`install.sh` · `autoinstall.sh` · `update_harbor_config.sh` · `common.sh`)는 `100644` 이며 실행 비트가 필요 없습니다: `common.sh` 는 `install.sh` 가 `source` 하고(`install.sh:6`), 나머지는 `bash <스크립트>` 형태로 실행합니다(`autoinstall.sh` 도 내부에서 `bash install.sh` 로 호출). `bash update_harbor_config.sh` 로 `harbor.yml` 을 만든 뒤 `sudo bash install.sh` 로 설치하며, `sudo bash autoinstall.sh` 는 두 단계를 한 번에 실행합니다 (설치는 root — `prepare` 가 root 600 env 파일을 만들어 일반 사용자 실행은 `[Step 4]` 에서 permission denied. 경로 입력·https 인증서 배치는 [devspoon-startup-web] 가이드의 Harbor 절 참고).
- **공존**: Harbor 는 자체 nginx 로 http 포트(기본 80)를 씁니다. 이 저장소의 웹 스택·master_service·단독 proxy 와 같은 호스트라면 **별도 호스트를 권장**하고, 같은 호스트라면 `update_harbor_config.sh` 에서 다른 http 포트를 지정한 뒤 앞단 nginx(예: master_service proxy conf)에서 그 포트로 프록시하세요.

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
   sudo chown root:root ~/.ssh/tizen_authorized_keys   # authorized_keys 만 root 소유 — 개인키 tizen_id_rsa 는 본인 소유 600 그대로
   ```

   - `TIZEN_AUTHORIZED_KEYS` 파일은 **root 소유·600 이어야 합니다(필수)**. bind mount 는 호스트 파일 소유자(uid)를 컨테이너에 그대로 보이고, sshd `StrictModes` 는 root 가 아닌 사용자 소유 `/root/.ssh/authorized_keys` 를 거부합니다 — 본인 소유로 두면 `ssh -p 2221 root@127.0.0.1` 이 `Permission denied (publickey)` 로 실패합니다. `TIZEN_SSH_KEY`(`tizen_id_rsa`)는 본인 소유 600 그대로 두면 됩니다(컨테이너 root 가 읽음). root 소유로 바꾼 뒤에는 이 파일에 공개키를 추가하거나 권한을 바꿀 때 `sudo` 가 필요합니다 — 위 블록을 그대로 다시 실행하면 `chmod 600` 이 `Operation not permitted` 로 실패합니다.
   - 두 변수가 비어 있으면 compose 가 기동을 거부합니다. **경로가 틀리면** Docker 가 호스트에 root 소유 빈 디렉터리를 만들고 컨테이너는 그대로 기동되어 SSH 인증만 실패합니다 — 생긴 디렉터리를 지우고 `.env` 경로를 고친 뒤 다시 기동하세요.
   - If a user wants to access the tizen container directly for development, add a new location to "volumes" in the docker-compose.yml.

2. Update Tizen ssh config file

   - docker/tizen-env/.ssh/config

   ```shell
   Host tizen review.tizen.org
   Hostname review.tizen.org
   IdentityFile ~/.ssh/id_rsa
   # Update the User value below to the ID already registered on the Tizen official website.
   # (ssh_config 는 줄 끝 주석을 허용하지 않으므로 주석은 반드시 별도 줄에 둡니다)
   User Tizen_Account_ID
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

   - Requirements: Docker Engine with the Compose plugin (`docker compose`). Legacy `docker-compose` (v1) 명령은 쓰지 않습니다(번들 Harbor installer 제외).
   - How to build only Tizen Environment — 1단계의 `.env` 뒤, 저장소 루트에서 이동해 기동합니다(`--build` 는 업그레이드나 Dockerfile 변경 뒤 이미지를 다시 빌드합니다).

   ```sh
   cd compose/dev_env_service/tizen-env
   docker compose up -d --build
   ssh -p 2221 root@127.0.0.1    # SSH 는 기본 127.0.0.1:2221 에만 바인드 — 원격 허용은 .env 의 TIZEN_SSH_BIND=0.0.0.0
   ```

   - How to build full service (require setting [devspoon-web], [devspoon-startup-web]) — tizenenv 는 `docker-compose-php.yml` 에만 있습니다. 단독 tizen-env 와 컨테이너 이름(`tizenenv`)·포트(2221)가 같으므로 둘 중 하나만 기동합니다. plane/gitea/jenkins proxy 샘플 복사는 [devspoon-startup-web] 가이드의 master_service 절을 먼저 따릅니다.

   ```sh
   # 저장소 루트에서
   D=compose/master_service
   cp "$D/.env-example" "$D/.env"    # TIZEN_* 경로, PLANE_DOMAIN · PLANE_WEB_URL · PLANE_CORS_ALLOWED_ORIGINS · GITEA_DOMAIN · GITEA_ROOT_URL 자리표시자는 직접 입력
   bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
   cd "$D"
   docker compose -f docker-compose-php.yml up -d --build                    # php + plane · jenkins · gitea · tizenenv
   docker compose -f docker-compose-php.yml --profile redis up -d --build    # + redis
   docker compose -f docker-compose-php.yml --profile redis stop             # 프로필 없는 stop 은 redis 컨테이너를 남깁니다
   ```

   php 조합의 프로필은 `redis` 뿐입니다(celery 없음).

   > ⚠️ **첫 기동은 Plane 마이그레이션 때문에 수 분 걸립니다**: `plane-migrator` 가 성공으로 끝난 뒤 `plane-api` 가 뜨고, 그 뒤에 `plane-proxy` 가 준비됩니다. 그 전까지 nginx 는 502 를 돌려줄 수 있습니다. Plane · Gitea 데이터는 named volume 이므로 호스트 폴더(`pgdata/` 등)를 만들 필요가 없습니다 — 위 [Plane · Gitea 데이터 볼륨](#plane--gitea-데이터-볼륨) 참고.
   >
   > ⚠️ **`PLANE_DB_PASSWORD` 를 나중에 바꾸면 기존 볼륨과 어긋납니다**: 이 값은 `plane-pgdata` 볼륨이 처음 만들어질 때의 PostgreSQL 비밀번호로 굳습니다. `.env` 를 새로 만들어 값이 바뀌면 `plane-migrator` 가 `FATAL: password authentication failed for user "plane"` 으로 실패하고 뒤따르는 앱 컨테이너가 전부 기동하지 못합니다. DB 안의 비밀번호도 함께 바꾸거나(`docker compose -f docker-compose-php.yml exec plane-db psql -U plane -c "ALTER USER plane PASSWORD '<새 값>';"`), 데이터를 버려도 되면 볼륨을 새로 만드세요(`down -v`).


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

- System integration between jenkins, gitea, tizen-env.
- Development tizen image management solution.
  - The tizen image management solution UI sample design

## Community

- **Personal Website** : Owner's personal website is devspoon.com

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com
  Personal site : devspoon.com

- Lim Tae-youn Member, Tizen Designer
- Kang Dong-hoon Member, Tizen Developer

### How to contributing our project

- devspoon-startup-tizen code is hosted and maintained using [GitHub](https://github.com/devspoons/devspoon-startup-tizen).
  We plan to contribute to third-party tools in the Tizen official repository(https://review.tizen.org/git/).
- To contribute to devspoon-startup-tizen, please refer to [GitHub](https://github.com/devspoons/devspoon-startup-tizen). It
  should includes most of the things you'll need to get your contribution started!

<!-- Markdown link & img dfn's -->

[devspoon-web]: https://github.com/devspoons/devspoon-web
[devspoon-startup-web]: https://github.com/devspoons/devspoon-startup-web
[Plane]: https://plane.so/
[Plane docs]: https://developers.plane.so/self-hosting/overview
[Jenkins]: https://en.wikipedia.org/wiki/Jenkins_(software)
[Gitea]: https://about.gitea.com/
[Gitea docs]: https://docs.gitea.com/installation/install-with-docker
[Harbor]: https://en.wikipedia.org/wiki/Harbor
[tizen web-site]: https://www.tizen.org/user/register
