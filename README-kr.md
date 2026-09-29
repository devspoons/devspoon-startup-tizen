# devspoon-startup-tizen

[English](README.md) · **[한국어](README-kr.md)**

devspoon-startup-tizen 은 Docker 로 신뢰할 수 있는 Tizen 개발 환경을 쉽게 구축하는 오픈소스 솔루션입니다.

## 기반 프로젝트

devspoon-startup-tizen 은 스타트업을 위한 통합 관리 솔루션 [devspoon-startup-web] 위에 얹혀 있습니다. nginx 기반 PHP · Python 플랫폼으로 웹과 API 를 개발할 수 있고, 스타트업에 중요한 프로젝트 솔루션(Plane · Jenkins · Gitea(사설 git 서버) · Harbor(사설 Docker 레지스트리))을 설치 · 백업 · 관리할 수 있습니다.

## "Devspoon-Projects" 소개

Docker Compose 로 Python · Django · PHP 등을 쉽게 서비스할 수 있는 오픈소스 인프라 통합 솔루션을 제공합니다. 상용 수준으로 커스터마이징 가능한 nginx 와 redis 를 한 번에 설치하고, 더 많은 서비스를 함께 설치 · 관리할 수 있습니다. 관심 있으시면 [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects) 를 방문하세요.

## 공식 가이드 문서

- 준비 중입니다.

## 프로젝트 관리 솔루션

| 솔루션 | 무엇을 하는가 | 컨테이너 | 설치 방식 | 상세 (원본 저장소) |
|---|---|---|---|---|
| **[Plane](#plane)** | 프로젝트 관리 — 이슈 · 사이클 · 모듈 | 13개 | compose (단독 / 통합) | [makeplane/plane](https://github.com/makeplane/plane) |
| **[Jenkins](#jenkins)** | CI — 빌드 · 테스트 · 배포 자동화 | 2개 | compose (단독 / 통합) | [jenkinsci/jenkins](https://github.com/jenkinsci/jenkins) |
| **[Gitea](#gitea)** | 자체 호스팅 git 서비스 | 1개 | compose (단독 / 통합) | [go-gitea/gitea](https://github.com/go-gitea/gitea) |
| **[Harbor](#harbor)** | 사설 Docker 레지스트리 | installer 가 생성 | **자체 installer** (별도 호스트 권장) | [goharbor/harbor](https://github.com/goharbor/harbor) |

### Plane

공식 사이트: [Plane] · 자체 호스팅 문서: [Plane docs]

이슈로 일을 쪼개고 주기로 묶어 굴리는 오픈소스 프로젝트 관리 도구입니다(Jira · Linear 와 같은 부류).

| 개념 | 설명 |
|---|---|
| 인스턴스 → 워크스페이스 → 프로젝트 → 이슈 | 위에서 아래로 포개지는 계층. 인스턴스 설정은 God Mode(`/god-mode/`) |
| 사이클(Cycle) | 기간으로 묶은 이슈 모음 — 스프린트 |
| 모듈(Module) | 기능 · 목표로 묶은 이슈 모음 — 기간과 무관 |

주요 기능: 보드 · 리스트 · 캘린더 · 간트 다중 뷰, 번다운 차트, **여러 명이 동시에 편집하는 페이지**, 외부 공개 공유, 첨부(S3 호환 저장소), REST API.
컨테이너 13개(앱 5 · 워커 2 · 마이그레이터 · DB · Redis · RabbitMQ · MinIO · 내부 프록시)가 한 묶음이라 이 저장소에서 가장 무겁고, 첫 기동에 수 분 걸립니다.

### Jenkins

공식 사이트: [Jenkins]

정해 둔 작업을 자동으로 실행해 주는 CI/CD 서버입니다. "코드가 올라오면 빌드하고 테스트하고 배포한다" 를 사람 손 없이 반복합니다.

| 개념 | 설명 |
|---|---|
| Job / Pipeline | 실행할 작업의 정의. 저장소의 `Jenkinsfile` 에 파이프라인을 적습니다 |
| Trigger | 실행 조건 — git push 웹훅, 주기 실행(cron), 수동, 다른 Job 성공 시 |
| Agent / Node | 실제로 작업을 돌리는 실행기 |
| Credentials · Plugin | 자격증명 보관과 기능 확장 |

**Tizen 개발에서의 쓰임**: GBS(Tizen Build Server)와 연동해 이미지 빌드를 자동화할 수 있습니다(아래 [Tizen 개발 환경 구축](#tizen-개발-환경-구축) 참고).
데이터는 `jenkins_home` 한 폴더에 쌓이며, 이미지가 uid 1000 으로 동작해 1회성 `jenkins-init` 이 기동 전에 소유권을 맞춥니다.

### Gitea

공식 사이트: [Gitea] · docker 설치 문서: [Gitea docs]

사내에 두는 GitHub 입니다. 저장소 호스팅에 웹 UI · 이슈 · 풀 리퀘스트 · 권한 관리가 딸려 오고, 컨테이너 하나로 돕니다.

| 항목 | 내용 |
|---|---|
| 접근 | **SSH**(공개키 등록 후 `ssh://git@<도메인>:2222/…`) 와 **HTTP**(비밀번호 · 토큰) |
| 웹훅 | push · PR 이벤트를 외부로 알립니다 — Jenkins 자동 빌드 연동이 여기서 나옵니다 |
| DB | 기본 내장 SQLite. 규모가 커지면 `.env` 에 `GITEA__database__*` 로 외부 DB 전환 |
| 데이터 | named volume `gitea-data` 하나(저장소 · DB · SSH 호스트키) |

기본값이 **가입 차단**(`GITEA_DISABLE_REGISTRATION=true`)이라 계정은 관리자가 만듭니다.

### Harbor

공식 사이트: [Harbor]

사내에 두는 Docker Hub 입니다. 컨테이너 이미지를 외부에 올리지 않고 직접 보관 · 배포합니다.

| 항목 | 내용 |
|---|---|
| 프로젝트 | 이미지를 담는 단위. public / private 와 멤버 역할을 정합니다 |
| 로봇 계정 | CI 전용 자격증명 — 사람 계정과 분리 |
| 취약점 스캔 · 서명 | push 된 이미지의 CVE 검사, 서명된 이미지만 배포 강제 |
| 복제 · 보존 | 다른 레지스트리와 동기화, 오래된 태그 정리 |

**Tizen 개발에서의 쓰임**: 스마트 TV · IoT 보드의 종류 · 버전 · 커널 환경별로 독립된 이미지를 만들어 두고, 새 서버에서 언제든 내려받아 설치할 수 있습니다.

> ⚠️ 설치 방식이 다른 셋과 **완전히 다릅니다** — compose 정의가 아니라 Harbor 공식 installer 를 씁니다. 자체 nginx 로 80 포트를 잡으므로 **별도 호스트를 권장**합니다. `harbor.yml` 의 `hostname` 에는 루프백 IP(`127.0.0.1`)를 쓸 수 없습니다.

## 특징

- **서비스별 설정 파일 생성 지원(conf · yml 등)** : 셸 스크립트로 nginx · php · dockerfile 등에 필요한 설정 파일을 사용자 입력만으로 쉽게 만들고 관리합니다.

- **개발과 서비스 운영을 함께 고려한 dockerfile 구성** : 로그 폴더를 `volumes` 로 연결해 컨테이너가 멈춰도 문제를 추적할 수 있습니다. 개발 중 자주 고치는 웹루트 · nginx 설정 등도 `volumes` 로 연결합니다.

- **리버스 프록시 제공** : nginx 하나로 PHP · Python 웹/앱 서비스와 프로젝트 관리 서비스를 동시에 제공합니다. 다른 서비스의 웹 UI 연동용 proxy 설정 파일을 쉽게 만드는 셸 스크립트를 제공합니다.

- 검증된 Dockerfile 과 Docker Compose 로 삼성 Tizen 기반 IoT 기기 개발에 필요한 복잡한 구성을 쉽게 구축합니다.

- [devspoon-startup-web] 이 제공하는 Jenkins 로 개발 자동화(CI)를 구성하고, Plane 으로 프로젝트를 효율적으로 관리합니다.

- Gitea 를 Plane · Jenkins 와 연동하면 저장소 공개 여부나 용량 제한 없이 효율적으로 쓸 수 있습니다.

- Harbor 로 스마트 TV · IoT 개발 보드의 종류 · 버전 · 커널 환경에 맞는 독립 Docker 이미지를 만들어 두고, 새 서버에 언제든 내려받아 설치할 수 있습니다.

- devspoon-startup-tizen 을 구성해 두면 내부망으로 이동했을 때도 다양한 조건의 개발 환경을 만들고, 인터넷 연결이 없어도 소스와 프로젝트를 관리할 수 있습니다.

## 고려 사항

- **DB 서비스 미제공** : 안정적인 운영을 위해 DB 는 docker 로 제공하지 않습니다. 실제 서버에 설치하고 3306 같은 포트로 네트워크 접근하는 방식을 권장합니다.

- **개발 지향 docker 서비스** : 수정과 테스트가 잦은 스타트업이나 신규 서비스 개발팀에 적합합니다.

- **AWS · GCM 이 아닌 일반 서버 대상** : 직접 운영하는 서버와 일반 서버 호스팅을 대상으로 합니다. AWS · GCM 등 클라우드 연동은 계획 중입니다.

- **Docker Compose 2.20 이상 필요** : Plane · Gitea 정의를 `compose/common/{plane-services,gitea-service}.yml` 한 곳에 두고 master_service 5조합과 단독 스택이 `include:` 로 참조합니다. 2.20 미만에서는 `include:` 를 인식하지 못해 `docker compose config` 부터 실패합니다.

- **git over SSH 는 호스트 2222** : Gitea 컨테이너가 호스트 `2222`(`GITEA_SSH_PORT`)를 직접 게시합니다. 클라우드라면 방화벽 · 보안 그룹(예: OCI VCN 보안 목록)에도 인바운드 2222 를 열어야 외부에서 SSH clone 이 됩니다 — Docker 가 게시한 포트는 호스트 iptables 의 INPUT 체인을 거치지 않으므로 호스트 방화벽만 열면 그대로 막혀 있습니다. 단독 tizen-env 는 2221 을 쓰므로 둘은 겹치지 않습니다.

- **Tizen 환경 제약 (잔여 위험)**
  - tizen-env 이미지는 빌드 검증을 하지 않았습니다. 베이스 이미지가 `ubuntu:18.04` 입니다(Tizen 도구 apt 소스가 Ubuntu 18.04 전용 — `docker/tizen-env/Dockerfile`). CI(`script/ci/repo-steps.sh`)는 tizen-env 를 빌드 · 기동하지 않고 compose 렌더 · SSH 포트 · 키 fail-fast · sshd 설정만 정적으로 검사합니다.
  - tizen-env · tizenenv 는 `privileged: true` 입니다 — Tizen mic 이미지 생성의 loop mount 용으로 빌드 검증 전까지 유지합니다(대체 후보 `cap_add: [SYS_ADMIN]` + `devices: [/dev/loop-control]`). 컨테이너가 호스트 장치에 접근할 수 있으므로 신뢰하는 호스트에서만 기동하세요.
  - master_service 의 `docker-compose-php.yml` 은 tizenenv 를 항상 포함하므로 Tizen 을 쓰지 않아도 `.env` 에 `TIZEN_SSH_KEY` · `TIZEN_AUTHORIZED_KEYS` 가 있어야 합니다(비어 있으면 `docker compose` 가 거부). 다른 master 조합(gunicorn · uvicorn · uwsgi · daphne)에는 tizenenv 가 없습니다.
  - 단독 tizen-env 와 master php 조합의 tizenenv 는 컨테이너 이름(`tizenenv`) · 포트(2221)가 같아 동시에 기동할 수 없습니다.
## 설치와 기동

### 웹 스택 & CI

웹 스택 서술은 정본 [devspoon-web] README 와 같습니다(이 저장소 구조에 맞춤). 모든 명령은 저장소 루트 기준입니다.

#### 스택 5종

| 스택 | compose 폴더 | app 서비스 | nginx 설정 폴더 | 프로파일 | 호스트 포트 |
|---|---|---|---|---|---|
| gunicorn | `compose/web_service/nginx_gunicorn` | `gunicorn-app` | `config/web-server/nginx/gunicorn` | `celery` | 80, 443, `127.0.0.1:5555`(flower) |
| uvicorn | `compose/web_service/nginx_uvicorn` | `uvicorn-app` | `config/web-server/nginx/uvicorn` | `celery` | 80, 443, `127.0.0.1:5555` |
| uwsgi | `compose/web_service/nginx_uwsgi` | `uwsgi-app` | `config/web-server/nginx/uwsgi` | `celery` | 80, 443, `127.0.0.1:5555` |
| daphne | `compose/web_service/nginx_daphne` | `daphne-app` | `config/web-server/nginx/gunicorn` (공유) | `celery` | 80, 443, `127.0.0.1:5555` |
| php 8.4 | `compose/web_service/nginx_php` | `php-app` | `config/web-server/nginx/php` | `redis` | 80, 443 |

- Python 스택은 `webserver` · app · `redis` 가 항상 뜨고, `--profile celery` 가 `celery` · `celery-beat` · `flower` 를 더합니다. php 스택은 `webserver` · `php-app` 이 뜨고 `--profile redis` 가 `redis` 를 더합니다.
- 모든 스택이 80/443 을 쓰므로 한 호스트에서 한 스택만 기동합니다.
- 샘플 앱: Python 스택은 `www/django_sample`, php 스택은 `www/php_sample`.

#### 1. `.env` 비밀값 생성 (최초 설정 · 업그레이드)

`.env-example` 의 비밀값은 **빈 값**입니다(Python 스택 `DJANGO_SECRET_KEY` · `REDIS_PASSWORD` · `FLOWER_PWD`, php 스택 `REDIS_PASSWORD`). compose 가 `${VAR:?}` 로 요구하므로 비워 둔 채로는 기동이 거부됩니다. 저장소 루트에서 스택마다 한 번:

```bash
D=compose/web_service/nginx_gunicorn
cp "$D/.env-example" "$D/.env"
bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
```

- 값이 비었거나 옛 `CHANGE_ME_*` 인 비밀 키만 `openssl rand -hex` 무작위 값으로 채웁니다(`DJANGO_SECRET_KEY` 100 hex, `*_KEY_BASE` 128 hex, 그 외 64 hex). 이미 값이 있는 키는 바꾸지 않습니다.
- 같은 폴더의 임시 파일에 쓴 뒤 교체하며, 값을 생성했으면 권한을 600 으로 좁힙니다(더 엄격하면 유지). openssl 이 없거나 실패하면 `FAIL` 로 끝나고 `.env` 내용은 바뀌지 않습니다.
- **비밀이 아닌 자리표시자는 헬퍼가 채우지 않습니다.** 운영 전에 직접 입력하세요.

  | 키 | 어디에 | 값 |
  |---|---|---|
  | `FLOWER_ID` | 웹 스택 · master | flower 로그인 ID (기본값 `CHANGE_ME_FLOWER_USER`) |
  | `DJANGO_ALLOWED_HOSTS` | 웹 스택 · master | 서비스할 도메인 추가 |
  | `PLANE_DOMAIN` · `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS` | master · 단독 plane | 셋 다 같은 도메인. proxy conf 의 `server_name` 과도 같아야 합니다 |
  | `GITEA_DOMAIN` · `GITEA_ROOT_URL` | master · 단독 gitea | 도메인과 전체 URL |

- 호스트에서 `manage.py` 를 직접 실행할 때만 `www/django_sample` 의 `secrets.json` 이 필요합니다: `bash -c '. script/lib/django_secrets.sh && ensure_django_secrets'` (없을 때만 생성, 600). 컨테이너는 `DJANGO_SECRET_KEY` 환경변수를 씁니다.

> **업그레이드 노트 — 이전 버전에서 쓰던 `.env` 를 유지하는 경우**
>
> 옛 `.env` 에는 `DJANGO_SECRET_KEY` 줄이 아예 없거나 `CHANGE_ME_*` 값이 남아 있을 수 있습니다. 같은 `.env` 에 위 헬퍼를 한 번 실행하면 정리됩니다.
>
> 헬퍼는 이렇게 동작합니다.
>
> - **어디를 보는가**: 같은 폴더의 `docker-compose*.yml`, 그리고 그 파일들이 `include:` 로 참조하는 조각(`compose/common/*.yml`).
> - **무엇을 찾는가**: 그 파일들이 `:?` 로 요구하는 키 중 이름에 SECRET · PASSWORD · PWD 가 들어가거나 `_KEY_BASE` 로 끝나는 것.
> - **무엇을 하는가**: 없는 키는 파일 끝에 추가하고, `CHANGE_ME_*` 는 새 값으로 바꿉니다. 이미 값이 있는 키는 건드리지 않고, 파일 권한을 600 으로 맞춥니다.
>
> `KEY=""` 처럼 따옴표로 감싼 빈 값은 채우지 않습니다. 먼저 `KEY=` 로 고쳐 두세요.
>
> 이전 버전은 `compose/web_service/*` · `compose/master_service` · `compose/project_mng_service/*` · `compose/dev_env_service/tizen-env` 의 `.env` 를 git 으로 추적했습니다. 이 버전에서 추적이 해제되어 `git pull` 이 로컬 `.env` 를 지울 수 있으니 **pull 전에 `.env` 를 다른 곳에 복사**해 두세요. 이전에 저장소에 공개됐던 `secrets.json` · `.env` 의 키로 운영 중이라면 새 값으로 교체하세요(세션 무효화).

#### 2. 기동

§1 의 `.env` 명령(저장소 루트) 뒤, 스택 폴더로 이동해 기동합니다. `--build` 는 업그레이드나 Dockerfile · `uv.lock` 변경 뒤 이미지를 다시 빌드합니다. 한 호스트에 한 스택만 띄웁니다.

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

> ⚠️ **`docker compose down -v` 는 named volume 을 삭제합니다.** 웹 스택의 앱 데이터, master_service 의 Plane 데이터(`plane-pgdata` 등), Gitea 저장소(`gitea-data`)가 모두 여기에 해당합니다. 컨테이너만 내릴 때는 `stop` 을 쓰세요.

- **기동 순서 — app 이 DB 를 초기화한 뒤 celery · beat 가 뜹니다.**
  DB 초기화는 app 서비스 **하나만** 수행합니다. `manage.py` 가 있으면 `python manage.py migrate --noinput`, 없으면 프로젝트의 `prestart.sh` 를 돌립니다.
  `celery` · `celery-beat` 는 `depends_on: <app>: condition: service_healthy` 로 묶여 app 이 healthy 가 된 뒤에 뜹니다. 여러 컨테이너가 동시에 migrate 하는 경쟁이 없습니다.
- **Flower 는 `127.0.0.1:5555` 에만 바인드**됩니다. 원격 접근은 SSH 터널을 쓰세요: `ssh -L 5555:127.0.0.1:5555 <host>` 후 로컬 브라우저에서 `http://127.0.0.1:5555`.
- `DJANGO_DEBUG`(기본 `0`) · `DJANGO_ALLOWED_HOSTS` 를 `.env` 로 제어하며 app · celery · beat 에 전달됩니다. `DJANGO_DEBUG=1` 은 로컬 개발에서만 쓰세요.
- 컨테이너는 `docker compose stop` / `start` / `restart` 로 운영합니다. 프로필 서비스까지 대상이면 기동과 같은 프로필을 붙입니다(`docker compose --profile celery stop`, php 는 `--profile redis stop`) — 프로필 없는 `stop` 은 celery · celery-beat · flower(php 는 redis) 컨테이너를 남깁니다.

#### 3. 이미지 이름 · 빌드 · uv

- **이미지 이름**은 `${IMAGE_NAMESPACE:-devspoon}-nginx:latest` 형식입니다(`-py-app:latest` · `-uwsgi-app:latest` · `-php-app:8.4`). 기본값이면 `devspoon-*` 태그가 됩니다.

  테스트는 운영 태그를 덮어쓰지 않도록 다른 네임스페이스를 씁니다 — 검증기와 `verify-ngxblocker.sh` 는 `IMAGE_NAMESPACE=devspoon-it`, run-ci 의 빌드 단계(`s2_build.sh`)는 `devspoon-test/*`.
- 앱 이미지(`py-app` · `uwsgi-app`)의 사전 설치 패키지는 `www/django_sample/uv.lock` 에서 도출됩니다. compose 가 `build.additional_contexts: lock: ../../../www/django_sample` 로 자동 전달하므로 **Docker Compose ≥ 2.17** 이 필요합니다(`docker compose version`).
- Compose 가 2.17 미만이거나 `docker build` 를 직접 쓸 때는 추가 빌드 컨텍스트를 명시합니다(저장소 루트, BuildKit):

  ```bash
  docker build --build-context lock=www/django_sample -t devspoon-py-app:latest docker/gunicorn/
  docker build --build-context lock=www/django_sample -t devspoon-uwsgi-app:latest docker/uwsgi/
  ```

  빠뜨리면 빌드가 `"/pyproject.toml": not found` 로 실패합니다.
- **uv** — `www/django_sample` 의 의존성은 `pyproject.toml` · `uv.lock` 으로 관리합니다. 컨테이너는 가상환경 없이 시스템 Python 에 설치하고(`UV_PROJECT_ENVIRONMENT=/usr/local`), 기동 명령이 `uv sync --inexact --extra <stack> --extra celery` 를 실행합니다. 같은 스택의 app · celery · celery-beat 는 같은 extras 로 sync 합니다.

  의존성을 추가할 때는 순서가 있습니다.

  ```bash
  cd www/django_sample && uv add <pkg>        # 1. 호스트에서 추가 → uv.lock 커밋
  cd compose/web_service/nginx_gunicorn        # 2. 스택 폴더로
  docker compose --profile celery stop
  docker compose up -d --build                 # 3. 앱 이미지 재빌드
  docker compose --profile celery up -d        # 4. celery · celery-beat 도 다시 올림
  ```

  4번을 빠뜨리면 celery 쪽이 옛 의존성으로 계속 돕니다. celery 서비스에는 `build:` 가 없어 app 과 같은 이미지를 참조만 하기 때문에, 프로필 없는 `up --build` 만으로는 교체되지 않습니다.

#### 4. nginx · php 설정

- **nginx conf 생성기** — `config/web-server/nginx/<gunicorn|uvicorn|uwsgi|php>/` 에 있는 `nginx_http_conf.sh` · `nginx_https_conf.sh` 가 `sample_nginx_http(s).conf` 를 바탕으로 도메인별 conf 를 `conf.d/` 에 만듭니다. 옵션은 `-h` 로 확인하세요. daphne 스택은 gunicorn 폴더를 그대로 씁니다.
- **nginx 기동 훅** — 이미지의 `/docker-entrypoint.d/30-wait-upstreams.sh` 가 conf 에 적힌 upstream(앱 컨테이너) 이름이 해석될 때까지 기다렸다가 nginx 를 띄웁니다. 대기 시간은 `NGINX_UPSTREAM_WAIT` 초(기본 30, `0` 이면 비활성)이며 webserver 의 `environment` 로 조정합니다.

  재부팅이나 `start` 처럼 app 보다 webserver 가 먼저 뜨는 상황에서 `[emerg] host not found in upstream` 으로 죽는 것을 막아 줍니다. 다만 전체 `docker compose restart` 는 모두가 동시에 재시작하므로 훅으로도 완전히 막히지 않습니다 — **conf 반영은 `nginx -s reload`, 전체 재기동은 `stop` → `start`** 를 쓰세요.
- **php-fpm pool 은 `config/app-server/php/pool.d/www.conf` 를 직접 편집**합니다. compose 가 읽기 전용으로 마운트하는 파일은 그 `www.conf` 와 `config/app-server/php/php_ini/php.ini` 둘뿐입니다. 그래서 `php_conf.sh` 가 `pool.d/` 에 만드는 `<DOMAIN>_php.conf` 는 로드되지 않습니다.

#### 5. CI — `script/ci/run-ci.sh`

##### 무엇을 위한 스크립트인가

저장소를 고친 뒤 **"이 저장소의 모든 스택이 여전히 실제로 뜨는가"** 를 한 번에 확인하는 회귀 테스트 묶음입니다. 문법 검사에서 끝나지 않고 컨테이너를 실제로 띄워 응답까지 받아 봅니다.

GitHub Actions(`.github/workflows/test.yml`)가 push 마다 같은 스크립트를 호출하고, 개발자가 로컬에서 `bash script/ci/run-ci.sh` 로 똑같이 돌릴 수도 있습니다.

##### 어떻게 동작하는가

11개 단계를 **순서대로** 실행하고, 한 단계라도 실패하면 **즉시 중단**합니다. 단계마다 로그를 `log/ci/` 에 남기고, 실패 시 "어느 단계에서 무슨 오류로" 실패했는지 로그 끝부분과 함께 알립니다.

| # | 단계 | 하는 일 |
|---|---|---|
| 1 | preflight | 필요한 도구·파일이 있는지, 설계 불변식이 지켜졌는지 확인 (읽기 전용) |
| 2 | prereq · 로그 디렉터리 | 테스트가 쓸 로그 폴더 생성 |
| 3 | nginx conf 생성기 | `nginx_http_conf.sh` · `nginx_https_conf.sh` 가 만든 conf 가 설정대로 나오는지 |
| 4 | compose 검증 | 모든 스택의 compose 문법과 마운트 경로 |
| 5 | 저장소 고유 검사 | `script/ci/repo-steps.sh` — 이 저장소에만 있는 규칙(Plane · Gitea · Jenkins · Harbor 관련 정적 단언) |
| 6 | 이미지 빌드 | 모든 Dockerfile 을 `devspoon-test/*` 태그로 빌드 (운영 태그를 덮어쓰지 않음) |
| 7 | 정적 회귀 | `s6_regression.sh` — 과거에 고친 결함이 되살아나지 않았는지 검사하는 불변식 모음 |
| 8 | healthcheck | 5개 스택의 healthcheck · `depends_on` 선언 검증 |
| 9 | 스택 매트릭스 | gunicorn · uvicorn · uwsgi · daphne · php 를 **차례로 실제 기동** — 200 응답, 봇 차단, healthy, 재시작 0회, DEBUG off, 업로드 경로 403 |
| 10 | 샘플 프로젝트 | django · php 샘플이 동작하는지 |
| 11 | 스크립트 로그 | 스크립트들이 로그를 제대로 남기는지 |

##### 실행 조건

- 실제 컨테이너를 띄우므로 **호스트 80 · 443 · 5555 포트가 비어 있어야** 합니다.
- 필요한 도구: docker(Compose ≥ 2.17), uv, jq, curl, openssl, php-cli.
- 알림은 선택입니다. 저장소 secrets 에 `SLACK_WEBHOOK_URL` · `TELEGRAM_BOT_TOKEN` · `TELEGRAM_CHAT_ID` 가 없으면 해당 알림만 건너뛰고 테스트는 그대로 진행합니다.
- 업로드하는 로그(`log/ci`, `log/test_run`)는 `script/lib/mask_secrets.sh` 로 비밀값을 가린 뒤 올립니다.

##### 쓰지 않으려면

CI 는 저장소 운영에만 쓰이고 서비스 기동과는 무관합니다. 필요 없으면 `.github/workflows/test.yml` 만 지우면 Actions 가 돌지 않고, `script/ci/` · `script/test_run/` 을 통째로 지워도 `compose/` 아래 서비스 기동에는 영향이 없습니다.

### 프로젝트 관리 솔루션 구축 (Plane · Jenkins · Gitea · Harbor)

`.env` · proxy 샘플 · 관리자 계정 생성 등 **상세 절차는 [devspoon-startup-web] 가이드를 따릅니다.** 이 저장소의 `compose/common/` · `compose/master_service/` · `compose/project_mng_service/` 정의는 그 저장소와 동일합니다. tizenenv 가 포함된 master php 조합 명령은 아래 [Tizen 개발 환경 구축](#tizen-개발-환경-구축) 4단계에 있습니다.

#### 통합 서비스 기동 — compose 파일 하나로 전부

`compose/master_service/` 의 compose 파일 **하나**를 실행하면 웹 스택 · Plane · Jenkins · Gitea 가 한 번에 뜨고, nginx 하나가 도메인별로 갈라 보냅니다.

| 파일 | 웹 스택 | 붙일 프로파일 | tizenenv |
|---|---|---|---|
| `docker-compose-php.yml` | php 8.4 | `--profile redis` | **포함** (컨테이너 18개) |
| `docker-compose-gunicorn.yml` | gunicorn | `--profile celery` | 없음 (17개) |
| `docker-compose-uvicorn.yml` | uvicorn | `--profile celery` | 없음 (17개) |
| `docker-compose-uwsgi.yml` | uwsgi | `--profile celery` | 없음 (17개) |
| `docker-compose-daphne.yml` | daphne | `--profile celery` | 없음 (17개) |

기동 절차(저장소 루트에서):

1. **`.env` 생성** — `cp compose/master_service/.env-example compose/master_service/.env` 후 `bash -c ". script/lib/django_secrets.sh && ensure_env_secrets compose/master_service/.env"`. 헬퍼가 `include:` 한 정의까지 훑어 Plane 비밀 키 5종을 채웁니다.
2. **자리표시자 직접 입력** — `DJANGO_ALLOWED_HOSTS` · `PLANE_DOMAIN` · `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS`(셋 다 같은 도메인) · `GITEA_DOMAIN` · `GITEA_ROOT_URL`, 그리고 php 조합이면 `TIZEN_SSH_KEY` · `TIZEN_AUTHORIZED_KEYS`.
3. **웹 앱 도메인 conf 생성** — 이 단계를 건너뛰면 저장소에 딸린 `localhost` conf 만 있어서 웹 앱 도메인 요청이 catch-all 에 걸려 **444** 로 끊깁니다.

   ```bash
   bash config/web-server/nginx/php/nginx_http_conf.sh -w php_sample -p 80 -d web.example.com -a php-app -s 9000
   ```

4. **proxy conf 3종 복사** — `config/web-server/nginx/php/proxy/{plane,jenkins,gitea}/` 의 `*_proxy.conf.example` 을 `*_proxy.conf` 로 복사하고 `server_name` 을 각 도메인으로 고칩니다.
5. **기동** — 아래 [Tizen 개발 환경 구축](#tizen-개발-환경-구축) 4단계의 명령을 씁니다.

운영 명령은 `-f docker-compose-<stack>.yml` 과 기동할 때 쓴 프로파일을 항상 함께 붙입니다. conf 반영은 `exec webserver nginx -s reload`, 전체 재기동은 `stop` → `start` 입니다(전체 `restart` 는 nginx 가 app 보다 먼저 떠 `[emerg]` 로 죽을 수 있습니다).

#### 단독 서비스 동시 기동 규칙

- **단독 서비스는 한 번에 하나만 기동합니다.** `nginx_plane` · `nginx_jenkins` 는 둘 다 호스트 80/443 을, `gitea` 는 2222 를 쓰고, `plane-*` · `jenkins` · `gitea` 컨테이너 이름이 master_service 와 같습니다. 웹 스택(`compose/web_service`) · master_service 와도 동시에 띄울 수 없습니다.
- **여러 서비스를 동시에 운영하려면 master_service 를 쓰세요.**
- **단독 스택은 HTTP 전용입니다(80 만, TLS 없음).** 443 은 매핑돼 있지만 catch-all `default.conf` 가 TLS 핸드셰이크를 거부할 뿐(`ssl_reject_handshake on`) 서비스용 TLS 서버 블록이 없어 로그인 자격증명이 평문으로 오갑니다. 공개망 운영은 앞단 TLS 종단 뒤에 두거나 master_service 를 쓰세요.
- 단독 tizen-env(`compose/dev_env_service/tizen-env`)는 호스트 포트 2221 만 쓰므로 웹 스택 · 단독 서비스와 함께 띄울 수 있지만, tizenenv 가 들어 있는 master php 조합과는 동시에 띄울 수 없습니다.
- 각 단독 스택의 기동 명령은 `cd compose/project_mng_service/<스택> && docker compose up -d --build` 입니다(세 스택 모두 nginx 이미지를 빌드합니다).

#### Plane · Gitea 데이터 볼륨

Plane 데이터(`plane-pgdata` · `plane-uploads` · `plane-rabbitmq` · `plane-redisdata` · `plane-proxy-*` · `plane-logs-*`)와 Gitea 저장소(`gitea-data`)는 호스트 bind 가 아니라 named volume 입니다 — 호스트 폴더를 미리 만들 필요가 없고 컨테이너 uid 와 호스트 계정의 소유권이 어긋나지 않습니다. 볼륨 이름 앞에는 compose 프로젝트(폴더) 이름이 붙습니다(단독 `gitea_gitea-data`, master `master_service_gitea-data` — `docker volume ls` 로 확인).

- **`docker compose down -v` 는 이 볼륨을 전부 삭제합니다.** 컨테이너만 내릴 때는 `stop` 을 쓰세요.
- 백업 · 복원 절차(Plane `pg_dump` · MinIO 업로드 아카이브, Gitea `gitea dump`)는 [devspoon-startup-web] 가이드의 Plane · Gitea 절을 따릅니다.

#### Harbor 공존

- 번들된 Harbor v2.0.0 installer(`compose/project_mng_service/harbor-v2.0.0/`)는 `docker compose` 플러그인이 아니라 **`docker-compose` 라는 이름의 명령**을 직접 호출합니다. `common.sh` 의 `check_dockercompose` 가 `docker-compose --version` 출력을 1.18.0 이상으로 파싱하지 못하면 `[Step 1]` 에서 중단하므로, 레거시 Compose v1 바이너리를 PATH 에 두거나 아래 래퍼를 만듭니다.

  ```bash
  printf '#!/bin/sh\ncase "$1" in --version|version) exec docker compose version ;; esac\nexec docker compose "$@"\n' \
    | sudo tee /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  ```

- 설치는 **root 로 실행합니다**: `cd compose/project_mng_service/harbor-v2.0.0 && sudo bash autoinstall.sh`. 일반 사용자로 돌리면 `prepare` 가 만든 root 소유 600 파일 때문에 `[Step 4]` 에서 멈춥니다. 경로 입력 · https 인증서 배치는 [devspoon-startup-web] 가이드의 Harbor 절을 참고하세요.
- **공존**: Harbor 는 자체 nginx 로 http 포트(기본 80)를 씁니다. 이 저장소의 웹 스택 · master_service · 단독 proxy 와 같은 호스트라면 **별도 호스트를 권장**하고, 같은 호스트라면 `update_harbor_config.sh` 에서 다른 http 포트를 지정한 뒤 앞단 nginx 에서 그 포트로 프록시하세요.

### Tizen 개발 환경 구축

- GBS(Tizen Build Server) 직접 구축: https://source.tizen.org/documentation/developer-guide/all-one-instructions/creating-tizen-images-scratch-one-page
- GBS 와 Jenkins(CI) 연동: https://source.tizen.org/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework

**1. SSH 키 준비**

- [tizen web-site] 에서 사용자 계정을 등록합니다.
- `ssh-keygen` 으로 키를 만들어 Tizen 공식 사이트에 등록해야 Tizen 저장소에 접근할 수 있습니다.
- Tizen Gerrit(https://review.tizen.org/gerrit) 에 로그인해 키를 올립니다 — Settings → "SSH Public Keys" 에 `id_rsa.pub` 추가.
- 키는 호스트에만 보관합니다 — 이미지에는 키가 들어가지 않습니다(`docker/tizen-env/.ssh` 에서는 `config` · `known_hosts` 만 복사하고, 그 폴더의 `id_rsa*` · `authorized_keys` 는 gitignore). compose 가 호스트 파일 두 개를 읽기 전용으로 bind 합니다.
  - `TIZEN_SSH_KEY` → `/root/.ssh/id_rsa` : Tizen Gerrit 에 등록한 개인키
  - `TIZEN_AUTHORIZED_KEYS` → `/root/.ssh/authorized_keys` : 컨테이너 root 로 SSH 접속을 허용할 공개키 목록(한 줄에 하나, 형식은 `docker/tizen-env/.ssh/authorized_keys.example`)

```sh
# 저장소 루트에서 — 단독 tizen-env. master php 조합은 D=compose/master_service (4단계)
D=compose/dev_env_service/tizen-env
cp "$D/.env-example" "$D/.env"      # TIZEN_SSH_KEY · TIZEN_AUTHORIZED_KEYS 를 실제 호스트 경로로 수정
chmod 600 ~/.ssh/tizen_id_rsa ~/.ssh/tizen_authorized_keys
sudo chown root:root ~/.ssh/tizen_authorized_keys   # authorized_keys 만 root 소유 — 개인키는 본인 소유 600 그대로
```

> ⚠️ **`TIZEN_AUTHORIZED_KEYS` 파일은 root 소유 · 600 이어야 합니다(필수).** bind mount 는 호스트 파일 소유자(uid)를 컨테이너에 그대로 보이고, sshd 의 `StrictModes` 는 root 가 아닌 사용자 소유 `/root/.ssh/authorized_keys` 를 거부합니다 — 본인 소유로 두면 `ssh -p 2221 root@127.0.0.1` 이 `Permission denied (publickey)` 로 실패합니다. `TIZEN_SSH_KEY`(`tizen_id_rsa`)는 본인 소유 600 그대로 두면 됩니다(컨테이너 root 가 읽습니다).
> root 소유로 바꾼 뒤에는 이 파일에 공개키를 추가하거나 권한을 바꿀 때 `sudo` 가 필요합니다 — 위 블록을 그대로 다시 실행하면 `chmod 600` 이 `Operation not permitted` 로 실패합니다.

- 두 변수가 비어 있으면 compose 가 기동을 거부합니다. **경로가 틀리면** Docker 가 호스트에 root 소유 빈 디렉터리를 만들고 컨테이너는 그대로 기동되어 SSH 인증만 실패합니다 — 생긴 디렉터리를 지우고 `.env` 경로를 고친 뒤 다시 기동하세요.
- 개발을 위해 컨테이너에 직접 접근하려면 `docker-compose.yml` 의 `volumes` 에 경로를 추가하세요.

**2. Tizen ssh config 수정** — `docker/tizen-env/.ssh/config`

```shell
Host tizen review.tizen.org
Hostname review.tizen.org
IdentityFile ~/.ssh/id_rsa
# 아래 User 값을 Tizen 공식 사이트에 등록한 ID 로 바꿉니다.
# (ssh_config 는 줄 끝 주석을 허용하지 않으므로 주석은 반드시 별도 줄에 둡니다)
User Tizen_Account_ID
Port 29418
# 프록시를 쓸 때만 아래 줄을 추가합니다.
# ProxyCommand nc -X5 -x <Proxy Address>:<Port> %h %p
```

**3. Gerrit 접근용 git 설정** — `docker/tizen-env/Dockerfile` 의 git 정보를 수정합니다.

```shell
git config --global user.name "ID"        # ID 입력
git config --global user.email "E-MAIL"   # E-MAIL 입력
```

**4. Docker Compose 실행**

- 요구 사항: Compose 플러그인이 포함된 Docker Engine(`docker compose`). 레거시 `docker-compose`(v1) 명령은 쓰지 않습니다(번들 Harbor installer 제외).
- **Tizen 환경만 구축** — 1단계의 `.env` 뒤, 저장소 루트에서 이동해 기동합니다.

  ```sh
  cd compose/dev_env_service/tizen-env
  docker compose up -d --build
  ssh -p 2221 root@127.0.0.1    # SSH 는 기본 127.0.0.1:2221 에만 바인드 — 원격 허용은 .env 의 TIZEN_SSH_BIND=0.0.0.0
  ```

- **전체 서비스 구축** ([devspoon-web] · [devspoon-startup-web] 설정 필요) — tizenenv 는 `docker-compose-php.yml` 에만 있습니다. 단독 tizen-env 와 컨테이너 이름(`tizenenv`) · 포트(2221)가 같으므로 둘 중 하나만 기동합니다.

  ```sh
  # 저장소 루트에서
  D=compose/master_service
  cp "$D/.env-example" "$D/.env"    # TIZEN_* 경로, PLANE_* · GITEA_* 자리표시자는 직접 입력
  bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
  cd "$D"
  docker compose -f docker-compose-php.yml up -d --build                    # php + plane · jenkins · gitea · tizenenv
  docker compose -f docker-compose-php.yml --profile redis up -d --build    # + redis
  docker compose -f docker-compose-php.yml --profile redis stop             # 프로필 없는 stop 은 redis 컨테이너를 남깁니다
  ```

  php 조합의 프로필은 `redis` 뿐입니다(celery 없음).

  > ⚠️ **첫 기동은 Plane 마이그레이션 때문에 수 분 걸립니다.** `plane-migrator` 가 성공으로 끝난 뒤 `plane-api` 가 뜨고, 그 뒤에 `plane-proxy` 가 준비됩니다. 그 전까지 nginx 는 502 를 돌려줄 수 있습니다. Plane · Gitea 데이터는 named volume 이므로 호스트 폴더(`pgdata/` 등)를 만들 필요가 없습니다 — [Plane · Gitea 데이터 볼륨](#plane--gitea-데이터-볼륨) 참고.
  >
  > ⚠️ **`PLANE_DB_PASSWORD` 를 나중에 바꾸면 기존 볼륨과 어긋납니다.** 이 값은 `plane-pgdata` 볼륨이 처음 만들어질 때의 PostgreSQL 비밀번호로 굳습니다. `.env` 를 새로 만들어 값이 바뀌면 `plane-migrator` 가 `FATAL: password authentication failed for user "plane"` 으로 실패하고 뒤따르는 앱 컨테이너가 전부 기동하지 못합니다. DB 안의 비밀번호도 함께 바꾸거나(`docker compose -f docker-compose-php.yml exec plane-db psql -U plane -c "ALTER USER plane PASSWORD '<새 값>';"`), 데이터를 버려도 되면 볼륨을 새로 만드세요(`down -v`).

**5. 선택 — 전체 저장소 동기화**

- 패키지를 내려받거나 기존 프로젝트를 쓰기만 한다면 이 단계는 필요 없습니다. 로컬 용량이 **수백 GB** 필요합니다.
- Tizen 저장소 패키지 전체를 로컬로 가져옵니다.
- 컨테이너의 `/root/repo-script` 에 있는 셸 스크립트로 `repo init` 을 실행합니다 — 전체용과 Raspberry Pi 3 용 두 가지가 있습니다.

**6. 샘플 프로젝트 테스트**

- `/root/samples` 에 anchor5 용과 Raspberry Pi 3 용 프로젝트가 있습니다.
- `peripheral-io` 패키지를 수정했다고 가정하고 빌드합니다.
  - 결과물은 `/Tizen-Work/mic-output` 의 `tizen-unified_iot-headed-3parts-armv7l-artik530.tar.gz` 입니다.

## 추가 개발 항목

- Jenkins · Gitea · tizen-env 간 시스템 연동
- Tizen 이미지 관리 솔루션 개발
  - Tizen 이미지 관리 솔루션 UI 샘플 디자인

## 커뮤니티

- **개인 웹사이트** : 운영자 개인 웹사이트는 devspoon.com 입니다.

## 파트너 및 사용자

- 임도현 Owner Developer/project Manager, bluebamus@gmail.com
  개인 사이트 : devspoon.com

- 임태연 Member, Tizen Designer
- 강동훈 Member, Tizen Developer

### 프로젝트 기여 방법

- devspoon-startup-tizen 코드는 [GitHub](https://github.com/devspoons/devspoon-startup-tizen) 에서 호스팅 · 관리됩니다.
  Tizen 공식 저장소(https://review.tizen.org/git/)의 서드파티 도구에도 기여할 계획입니다.
- 기여하려면 [GitHub](https://github.com/devspoons/devspoon-startup-tizen) 을 참고하세요. 시작하는 데 필요한 대부분의 내용이 들어 있습니다.

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
