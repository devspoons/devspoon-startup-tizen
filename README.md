# devspoon-startup-tizen

**[English](README.md)** · [한국어](README-kr.md)

devspoon-startup-tizen is an open source solution for building a reliable Tizen development environment easily with Docker.

## Based project

devspoon-startup-tizen is built on top of [devspoon-startup-web], an integrated management solution catered to startups. It provides nginx-based PHP and Python platforms for developing web and API services, and lets you install, back up and manage the project solutions a startup needs — Plane, Jenkins, Gitea (private git server) and Harbor (private Docker registry).

## Introducing "Devspoon-Projects"

We provide an open source infrastructure integration solution that makes it easy to serve Python, Django, PHP and more with Docker Compose. You can install a commercial-grade customizable nginx service and redis in one go, and install and manage more services together. If you are interested, visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

## Official guide document

- preparing...

## Project management solutions

| Solution | What it does | Containers | Install method | Details (upstream repository) |
|---|---|---|---|---|
| **[Plane](#plane)** | Project management — issues · cycles · modules | 13 | compose (standalone / all-in-one) | [makeplane/plane](https://github.com/makeplane/plane) |
| **[Jenkins](#jenkins)** | CI — automated build · test · deploy | 2 | compose (standalone / all-in-one) | [jenkinsci/jenkins](https://github.com/jenkinsci/jenkins) |
| **[Gitea](#gitea)** | Self-hosted git service | 1 | compose (standalone / all-in-one) | [go-gitea/gitea](https://github.com/go-gitea/gitea) |
| **[Harbor](#harbor)** | Private Docker Registry | created by installer | **its own installer** (separate host recommended) | [goharbor/harbor](https://github.com/goharbor/harbor) |

### Plane

Official site: [Plane] · self-hosting documentation: [Plane docs]

An open source project management tool that splits work into issues and groups them into cycles (same family as Jira and Linear).

| Concept | Description |
|---|---|
| Instance → workspace → project → issue | The nesting from the top down. Instance settings live in God Mode (`/god-mode/`) |
| Cycle | Issues grouped by a time box — a sprint |
| Module | Issues grouped by feature or goal, independent of time |

Main features: board, list, calendar and gantt views; burndown charts; **pages edited by several people at once**; public read-only sharing; attachments in an S3-compatible store; a REST API.
Its 13 containers (5 apps, 2 workers, a migrator, DB, Redis, RabbitMQ, MinIO and an in-stack proxy) make it the heaviest service here, and the first startup takes several minutes.

### Jenkins

Official site: [Jenkins]

A CI/CD server that runs the jobs you define automatically — it repeats "build, test and deploy when code lands" without anyone doing it by hand.

| Concept | Description |
|---|---|
| Job / Pipeline | The definition of the work to run, written into a `Jenkinsfile` in the repository |
| Trigger | What starts it — a git push webhook, a schedule (cron), a manual run, or another job succeeding |
| Agent / Node | The executor that actually runs the work |
| Credentials · Plugin | Credential storage and feature extensions |

**In Tizen development**: pair it with GBS (Tizen Build Server) to automate image builds (see [Building the Tizen development environment](#building-the-tizen-development-environment)).
All data lives in the single `jenkins_home` folder. The image runs as uid 1000, so a one-shot `jenkins-init` fixes the ownership before Jenkins starts.

### Gitea

Official site: [Gitea] · docker installation documentation: [Gitea docs]

GitHub for your own server. Repository hosting with a web UI, issues, pull requests and permissions, running in a single container.

| Item | Description |
|---|---|
| Access | **SSH** (register a public key, then `ssh://git@<domain>:2222/…`) and **HTTP** (password or token) |
| Webhooks | Announce push and PR events to the outside — this is what triggers Jenkins builds |
| Database | Embedded SQLite by default; move to an external DB with `GITEA__database__*` in `.env` |
| Data | One named volume, `gitea-data` (repositories, database, SSH host keys) |

Sign-up is **disabled by default** (`GITEA_DISABLE_REGISTRATION=true`), so an administrator creates the accounts.

### Harbor

Official site: [Harbor]

Docker Hub for your own site. Store and distribute container images yourself instead of pushing them outside.

| Item | Description |
|---|---|
| Project | The unit that holds images, with public/private setting and member roles |
| Robot account | A CI-only credential, separate from human accounts |
| Scanning · signing | Scans pushed images for CVEs; can enforce that only signed images are deployed |
| Replication · retention | Synchronises with other registries and prunes old tags |

**In Tizen development**: keep an independent image per smart TV / IoT board type, version and kernel environment, and pull it onto any new server whenever you need it.

> ⚠️ Its installation differs **completely** from the other three — it uses Harbor's official installer, not a compose definition. It takes port 80 with its own nginx, so **a separate host is recommended**. The `hostname` in `harbor.yml` cannot be a loopback IP (`127.0.0.1`).

## Features

- **Configuration file generators for each service (conf, yml and so on)** — shell scripts build and manage the configuration files nginx, php and the Dockerfiles need, from nothing more than your keyboard input.

- **Dockerfile layout aimed at both development and operation** — the log folder is wired through `volumes` so you can trace problems even when a container has stopped. Things you change often during development (webroot, nginx config) are wired the same way.

- **Reverse proxy** — a single nginx can serve several PHP and Python web/app services alongside the project management services. Shell scripts make the proxy configuration files for integrating other services' web UIs.

- devspoon-startup-tizen builds the complex setup needed to develop Samsung Tizen-based IoT devices from already verified Dockerfiles and Compose files.

- Development automation (CI) can be configured with the Jenkins provided by [devspoon-startup-web], and projects managed efficiently with Plane.

- Gitea integrates with Plane and Jenkins, so you get a git server without repository visibility or storage-capacity limits.

- With Harbor you can build an independent Docker image per smart TV / IoT board type, version and kernel environment, and download and install it on any new server at any time.

- Once devspoon-startup-tizen is set up, you can build development environments under many conditions and manage sources and projects even on an internal network with no internet connection.

## Considerations

- **No DB service** — for stable operation this project does not ship a database as a container. Install it on a real server and reach it over the network (port 3306 and the like). The same is worth considering for distributed services.

- **Development-oriented docker service** — a good fit for startups and new-service teams that change and test things often.

- **Aimed at plain servers, not AWS / GCM** — this project targets servers you operate yourself and general server hosting. Cloud integration (AWS, GCM and so on) is planned.

- **Docker Compose 2.20 or newer is required** — the Plane and Gitea definitions live in one place (`compose/common/{plane-services,gitea-service}.yml`) and the five master_service combinations and the standalone stacks pull them in with `include:`. Below 2.20, `include:` is not recognised and even `docker compose config` fails.

- **git over SSH uses host port 2222** — the Gitea container publishes host `2222` (`GITEA_SSH_PORT`) directly. On a cloud host you must also allow inbound 2222 in the firewall and the security group (an OCI VCN security list, for example) for SSH clone to work from outside. Ports published by Docker bypass the host's iptables INPUT chain, so a host firewall rule alone leaves it blocked. The standalone tizen-env uses 2221, so the two do not collide.

- **Tizen environment constraints (residual risk)**
  - The tizen-env image has not been build-verified. Its base image is `ubuntu:18.04` (the Tizen tooling apt source is Ubuntu 18.04 only — `docker/tizen-env/Dockerfile`). CI (`script/ci/repo-steps.sh`) does not build or start tizen-env; it only checks the compose rendering, SSH ports, key fail-fast behaviour and sshd settings statically.
  - tizen-env and tizenenv run with `privileged: true` — kept for the loop mount that Tizen mic image creation needs, until a build verification is done (the alternative being `cap_add: [SYS_ADMIN]` + `devices: [/dev/loop-control]`). The container can reach host devices, so only start it on a host you trust.
  - `docker-compose-php.yml` in master_service always includes tizenenv, so `.env` needs `TIZEN_SSH_KEY` and `TIZEN_AUTHORIZED_KEYS` even if you do not use Tizen (compose refuses to start when they are empty). The other master combinations (gunicorn, uvicorn, uwsgi, daphne) have no tizenenv.
  - The standalone tizen-env and the tizenenv inside the master php combination share a container name (`tizenenv`) and port (2221), so they cannot run at the same time.

## Install & Run

### Web stack & CI

The web stack description matches the canonical [devspoon-web] README, adapted to this repository's layout. Every command starts from the repository root.

#### The five stacks

| Stack | compose folder | app service | nginx config folder | Profile | Host ports |
|---|---|---|---|---|---|
| gunicorn | `compose/web_service/nginx_gunicorn` | `gunicorn-app` | `config/web-server/nginx/gunicorn` | `celery` | 80, 443, `127.0.0.1:5555` (flower) |
| uvicorn | `compose/web_service/nginx_uvicorn` | `uvicorn-app` | `config/web-server/nginx/uvicorn` | `celery` | 80, 443, `127.0.0.1:5555` |
| uwsgi | `compose/web_service/nginx_uwsgi` | `uwsgi-app` | `config/web-server/nginx/uwsgi` | `celery` | 80, 443, `127.0.0.1:5555` |
| daphne | `compose/web_service/nginx_daphne` | `daphne-app` | `config/web-server/nginx/gunicorn` (shared) | `celery` | 80, 443, `127.0.0.1:5555` |
| php 8.4 | `compose/web_service/nginx_php` | `php-app` | `config/web-server/nginx/php` | `redis` | 80, 443 |

- Python stacks always start `webserver`, the app and `redis`; `--profile celery` adds `celery`, `celery-beat` and `flower`. The php stack starts `webserver` and `php-app`, and `--profile redis` adds `redis`.
- Every stack uses ports 80/443, so run only one stack per host.
- Sample apps: `www/django_sample` for Python stacks, `www/php_sample` for the php stack.

#### 1. Generating `.env` secrets (first setup · upgrade)

The secrets in `.env-example` are **empty** (`DJANGO_SECRET_KEY`, `REDIS_PASSWORD`, `FLOWER_PWD` for Python stacks; `REDIS_PASSWORD` for php). Compose requires them with `${VAR:?}`, so startup is refused while they are blank. Run this once per stack, from the repository root:

```bash
D=compose/web_service/nginx_gunicorn
cp "$D/.env-example" "$D/.env"
bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
```

- Only secret keys that are empty or still hold the old `CHANGE_ME_*` placeholder are filled with `openssl rand -hex` values (`DJANGO_SECRET_KEY` 100 hex, `*_KEY_BASE` 128 hex, everything else 64 hex). Keys that already have a value are left alone.
- The helper writes to a temporary file in the same folder and swaps it in; if it generated anything, it tightens the permissions to 600 (stricter permissions are kept). If openssl is missing or fails it ends with `FAIL` and `.env` is untouched.
- **The helper does not fill non-secret placeholders — enter them yourself before going live.**

  | Key | Where | Value |
  |---|---|---|
  | `FLOWER_ID` | web stacks · master | flower login ID (default `CHANGE_ME_FLOWER_USER`) |
  | `DJANGO_ALLOWED_HOSTS` | web stacks · master | add the domain you serve |
  | `PLANE_DOMAIN` · `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS` | master · standalone plane | all three the same domain, matching `server_name` in the proxy conf |
  | `GITEA_DOMAIN` · `GITEA_ROOT_URL` | master · standalone gitea | the domain and the full URL |

- `www/django_sample/secrets.json` is only needed when you run `manage.py` directly on the host: `bash -c '. script/lib/django_secrets.sh && ensure_django_secrets'` (created only when missing, mode 600). Containers use the `DJANGO_SECRET_KEY` environment variable.

> **Upgrade note — keeping an `.env` from an older version**
>
> An old `.env` may have no `DJANGO_SECRET_KEY` line at all, or may still hold `CHANGE_ME_*` values. Running the helper once on that same `.env` fixes it.
>
> What the helper does:
>
> - **Where it looks**: `docker-compose*.yml` in the same folder, plus any fragment those files pull in with `include:` (`compose/common/*.yml`).
> - **What it looks for**: keys those files require with `:?` whose name contains SECRET, PASSWORD or PWD, or ends with `_KEY_BASE`.
> - **What it does**: appends missing keys at the end of the file and replaces `CHANGE_ME_*` with new values. Keys that already have a value are untouched, and the file mode is set to 600.
>
> A quoted empty value such as `KEY=""` is not filled. Change it to `KEY=` first.
>
> Older versions tracked the `.env` files under `compose/web_service/*`, `compose/master_service`, `compose/project_mng_service/*` and `compose/dev_env_service/tizen-env` in git. They are untracked now, so `git pull` may remove your local `.env` — **copy it somewhere safe before pulling.** If you are running with keys from a `secrets.json` or `.env` that was once public in the repository, replace them (this invalidates sessions).

#### 2. Starting a stack

After the `.env` commands in §1 (run from the repository root), move into the stack folder and start it. Add `--build` to rebuild images after an upgrade or a change to a Dockerfile / `uv.lock`. Run only one stack per host.

```bash
# gunicorn (from the repository root)
cd compose/web_service/nginx_gunicorn
docker compose up -d --build             # webserver + gunicorn-app + redis
docker compose --profile celery up -d    # + celery · celery-beat · flower
```

uvicorn, uwsgi and daphne use the same commands — only the folder name changes to `compose/web_service/nginx_uvicorn`, `nginx_uwsgi` or `nginx_daphne`.

```bash
# php (from the repository root)
cd compose/web_service/nginx_php
docker compose up -d --build             # webserver + php-app
docker compose --profile redis up -d     # + redis
```

> ⚠️ **`docker compose down -v` deletes named volumes**, including the web stack's app data, master_service's Plane data (`plane-pgdata` and friends) and Gitea's repositories (`gitea-data`). Use `stop` when you only want to bring the containers down.

- **Startup order — the app initialises the DB, then celery and beat start.**
  Only the app service initialises the database: `python manage.py migrate --noinput` if `manage.py` exists, otherwise the project's `prestart.sh`. `celery` and `celery-beat` are bound with `depends_on: <app>: condition: service_healthy`, so they start after the app is healthy. No two containers race to migrate.
- **Flower binds to `127.0.0.1:5555` only.** Reach it over an SSH tunnel: `ssh -L 5555:127.0.0.1:5555 <host>`, then open `http://127.0.0.1:5555` locally.
- `DJANGO_DEBUG` (default `0`) and `DJANGO_ALLOWED_HOSTS` are controlled through `.env` and passed to the app, celery and beat. Use `DJANGO_DEBUG=1` only for local development.
- Operate containers with `docker compose stop` / `start` / `restart`. Include the same profile you started with when profile services are involved (`docker compose --profile celery stop`, or `--profile redis` for php) — without it, `stop` leaves celery, celery-beat and flower (or redis) running.

#### 3. Image names · build · uv

- **Image names** follow `${IMAGE_NAMESPACE:-devspoon}-nginx:latest` (`-py-app:latest`, `-uwsgi-app:latest`, `-php-app:8.4`). With the default value you get `devspoon-*` tags.

  Tests use a different namespace so they never overwrite your production tags — the verifiers and `verify-ngxblocker.sh` use `IMAGE_NAMESPACE=devspoon-it`, and run-ci's build step (`s2_build.sh`) uses `devspoon-test/*`.
- The pre-installed packages in the app images (`py-app`, `uwsgi-app`) are derived from `www/django_sample/uv.lock`. Compose passes it automatically via `build.additional_contexts: lock: ../../../www/django_sample`, which needs **Docker Compose ≥ 2.17**  (`docker compose version`).
- If your Compose is older than 2.17, or you call `docker build` directly, pass the extra build context explicitly (from the repository root, with BuildKit):

  ```bash
  docker build --build-context lock=www/django_sample -t devspoon-py-app:latest docker/gunicorn/
  docker build --build-context lock=www/django_sample -t devspoon-uwsgi-app:latest docker/uwsgi/
  ```

  Leaving it out makes the build fail with `"/pyproject.toml": not found`.
- **uv** — dependencies for `www/django_sample` are managed with `pyproject.toml` and `uv.lock`. Containers install into the system Python without a virtualenv (`UV_PROJECT_ENVIRONMENT=/usr/local`), and the startup command runs `uv sync --inexact --extra <stack> --extra celery`. The app, celery and celery-beat of one stack sync with the same extras.

  Adding a dependency has an order to it:

  ```bash
  cd www/django_sample && uv add <pkg>        # 1. add on the host → commit uv.lock
  cd compose/web_service/nginx_gunicorn        # 2. into the stack folder
  docker compose --profile celery stop
  docker compose up -d --build                 # 3. rebuild the app image
  docker compose --profile celery up -d        # 4. bring celery · celery-beat back too
  ```

  Skip step 4 and celery keeps running with the old dependencies. The celery services have no `build:` of their own — they only reference the app's image — so `up --build` without the profile does not replace them.

#### 4. nginx · php configuration

- **nginx conf generators** — `nginx_http_conf.sh` and `nginx_https_conf.sh` under `config/web-server/nginx/<gunicorn|uvicorn|uwsgi|php>/` turn `sample_nginx_http(s).conf` into per-domain configs in `conf.d/`. Run with `-h` for the options. The daphne stack reuses the gunicorn folder.
- **nginx startup hook** — the image's `/docker-entrypoint.d/30-wait-upstreams.sh` waits until the upstream names (app containers) in the configs resolve before starting nginx. The wait is `NGINX_UPSTREAM_WAIT` seconds (default 30, `0` disables it), adjustable through the webserver's `environment`.

  This prevents nginx from dying with `[emerg] host not found in upstream` when it comes up before the app, such as after a reboot or a `start`. It cannot fully cover a whole-project `docker compose restart`, where everything restarts at once — **apply config changes with `nginx -s reload`, and restart everything with `stop` → `start`.**
- **Edit the php-fpm pool at `config/app-server/php/pool.d/www.conf`.** Compose mounts exactly two files read-only: that `www.conf` and `config/app-server/php/php_ini/php.ini`. Any `<DOMAIN>_php.conf` that `php_conf.sh` writes into `pool.d/` is therefore never loaded.

#### 5. CI — `script/ci/run-ci.sh`

##### What it is for

A regression suite that answers one question after you change the repository: **do all the stacks in it still actually come up?** It does not stop at syntax checks — it starts the containers and waits for real responses.

GitHub Actions (`.github/workflows/test.yml`) calls the same script on every push, and you can run `bash script/ci/run-ci.sh` locally for the same result.

##### How it works

It runs 11 steps **in order** and **stops immediately** on the first failure. Each step writes a log under `log/ci/`, and on failure it reports which step failed and why, with the tail of that log.

| # | Step | What it does |
|---|---|---|
| 1 | preflight | Checks the required tools and files exist and the design invariants hold (read-only) |
| 2 | prereq · log dirs | Creates the log folders the tests write to |
| 3 | nginx conf generators | Verifies the configs produced by `nginx_http_conf.sh` / `nginx_https_conf.sh` match the inputs |
| 4 | compose validation | Compose syntax and mount paths for every stack |
| 5 | repository-specific checks | `script/ci/repo-steps.sh` — rules unique to this repository (static assertions for Plane, Gitea, Jenkins, Harbor) |
| 6 | image builds | Builds every Dockerfile under `devspoon-test/*` tags (never overwriting production tags) |
| 7 | static regression | `s6_regression.sh` — invariants that catch previously fixed defects coming back |
| 8 | healthcheck | Validates the healthcheck and `depends_on` declarations of the five stacks |
| 9 | stack matrix | **Actually starts** gunicorn · uvicorn · uwsgi · daphne · php in turn — 200 responses, bot blocking, healthy, zero restarts, DEBUG off, 403 on upload paths |
| 10 | sample projects | Checks the django and php samples work |
| 11 | script logs | Checks the scripts write their logs properly |

##### Requirements

- It starts real containers, so **host ports 80, 443 and 5555 must be free.**
- Tools needed: docker (Compose ≥ 2.17), uv, jq, curl, openssl, php-cli.
- Notifications are optional. If the repository secrets `SLACK_WEBHOOK_URL`, `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are absent, only those notifications are skipped — the tests still run.
- Uploaded logs (`log/ci`, `log/test_run`) are masked with `script/lib/mask_secrets.sh` before upload.

##### If you do not want it

CI only serves repository maintenance; it has nothing to do with running the services. Delete `.github/workflows/test.yml` and Actions stops running. You can delete `script/ci/` and `script/test_run/` entirely without affecting anything under `compose/`.

### Building the project management solutions (Plane · Jenkins · Gitea · Harbor)

**Follow the [devspoon-startup-web] guide for the detailed steps** — `.env`, the proxy samples and administrator account creation. The `compose/common/`, `compose/master_service/` and `compose/project_mng_service/` definitions in this repository are identical to that one. The master php command that includes tizenenv is in step 4 of [Building the Tizen development environment](#building-the-tizen-development-environment) below.

#### All-in-one startup — one compose file for everything

Running **one** compose file from `compose/master_service/` brings up the web stack, Plane, Jenkins and Gitea together, with a single nginx splitting traffic by domain.

| File | Web stack | Profile to add | tizenenv |
|---|---|---|---|
| `docker-compose-php.yml` | php 8.4 | `--profile redis` | **included** (18 containers) |
| `docker-compose-gunicorn.yml` | gunicorn | `--profile celery` | no (17) |
| `docker-compose-uvicorn.yml` | uvicorn | `--profile celery` | no (17) |
| `docker-compose-uwsgi.yml` | uwsgi | `--profile celery` | no (17) |
| `docker-compose-daphne.yml` | daphne | `--profile celery` | no (17) |

Steps (from the repository root):

1. **Create `.env`** — `cp compose/master_service/.env-example compose/master_service/.env`, then `bash -c ". script/lib/django_secrets.sh && ensure_env_secrets compose/master_service/.env"`. The helper walks the `include:`d definitions and fills the five Plane secrets.
2. **Fill in the placeholders yourself** — `DJANGO_ALLOWED_HOSTS`, `PLANE_DOMAIN` · `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS` (all three the same domain), `GITEA_DOMAIN` · `GITEA_ROOT_URL`, and for the php combination `TIZEN_SSH_KEY` · `TIZEN_AUTHORIZED_KEYS`.
3. **Generate the web app's domain config** — skip this and only the bundled `localhost` config exists, so requests for your web domain hit the catch-all and are cut off with **444**.

   ```bash
   bash config/web-server/nginx/php/nginx_http_conf.sh -w php_sample -p 80 -d web.example.com -a php-app -s 9000
   ```

4. **Copy the three proxy configs** — copy `*_proxy.conf.example` to `*_proxy.conf` under `config/web-server/nginx/php/proxy/{plane,jenkins,gitea}/` and set each `server_name` to its domain.
5. **Start** — use the commands in step 4 of [Building the Tizen development environment](#building-the-tizen-development-environment) below.

Always pass `-f docker-compose-<stack>.yml` together with the profile you started with. Apply config changes with `exec webserver nginx -s reload`, and restart everything with `stop` → `start` (a whole-project `restart` can bring nginx up before the app and kill it with `[emerg]`).

#### Standalone concurrency rules

- **Run only one standalone service at a time.** `nginx_plane` and `nginx_jenkins` both take host 80/443, `gitea` takes 2222, and the `plane-*`, `jenkins` and `gitea` container names are the same ones master_service uses. They also cannot run alongside a web stack (`compose/web_service`) or master_service.
- **To run several services at once, use master_service.**
- **Standalone stacks are HTTP only (port 80, no TLS).** Port 443 is mapped, but the catch-all `default.conf` merely rejects the handshake (`ssl_reject_handshake on`) — there is no TLS server block for the service, so login credentials travel in clear text. For public networks put a TLS terminator in front, or use master_service.
- The standalone tizen-env (`compose/dev_env_service/tizen-env`) only uses host port 2221, so it can run alongside a web stack or a standalone service — but not alongside the master php combination, which contains tizenenv.
- Each standalone stack starts with `cd compose/project_mng_service/<stack> && docker compose up -d --build` (all three build the nginx image).

#### Plane · Gitea data volumes

Plane's data (`plane-pgdata`, `plane-uploads`, `plane-rabbitmq`, `plane-redisdata`, `plane-proxy-*`, `plane-logs-*`) and Gitea's repositories (`gitea-data`) live in named volumes, not host bind mounts — no host folders to create up front, and no ownership mismatch between the container uid and your host account. Volume names are prefixed with the compose project (folder) name: `gitea_gitea-data` standalone, `master_service_gitea-data` under master (check with `docker volume ls`).

- **`docker compose down -v` deletes all of these volumes.** Use `stop` when you only want to bring the containers down.
- For backup and restore (Plane `pg_dump` and the MinIO upload archive, Gitea `gitea dump`), follow the Plane and Gitea sections of the [devspoon-startup-web] guide.

#### Living alongside Harbor

- The bundled Harbor v2.0.0 installer (`compose/project_mng_service/harbor-v2.0.0/`) does not use the `docker compose` plugin — it calls a command literally named **`docker-compose`**. If `check_dockercompose` in `common.sh` cannot parse `docker-compose --version` as 1.18.0 or newer, it stops at `[Step 1]`. Put a legacy Compose v1 binary on the PATH, or create this wrapper.

  ```bash
  printf '#!/bin/sh\ncase "$1" in --version|version) exec docker compose version ;; esac\nexec docker compose "$@"\n' \
    | sudo tee /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  ```

- Install **as root**: `cd compose/project_mng_service/harbor-v2.0.0 && sudo bash autoinstall.sh`. As a normal user it stops at `[Step 4]` because `prepare` creates root-owned 0600 files. For the path prompts and https certificate layout, see the Harbor section of the [devspoon-startup-web] guide.
- **Coexistence**: Harbor takes an http port (80 by default) with its own nginx. On the same host as this repository's web stack, master_service or a standalone proxy, **a separate host is recommended**; if they must share one, choose a different http port in `update_harbor_config.sh` and proxy to it from the front nginx.

### Building the Tizen development environment

- Build GBS (Tizen Build Server) yourself: https://source.tizen.org/documentation/developer-guide/all-one-instructions/creating-tizen-images-scratch-one-page
- Interlock GBS with Jenkins (CI): https://source.tizen.org/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework

**1. Prepare an SSH key**

- Register a user account at the [tizen web-site].
- Create a key with `ssh-keygen` and register it on the official Tizen site to access the Tizen repository.
- Log in to Tizen Gerrit (https://review.tizen.org/gerrit) and upload the key — Settings → "SSH Public Keys" → add your `id_rsa.pub`.
- Keys stay on the host; none are baked into the image. (`docker/tizen-env/.ssh` only copies `config` and `known_hosts`; `id_rsa*` and `authorized_keys` in that folder are gitignored.) Compose bind-mounts two host files read-only.
  - `TIZEN_SSH_KEY` → `/root/.ssh/id_rsa` : the private key registered with Tizen Gerrit
  - `TIZEN_AUTHORIZED_KEYS` → `/root/.ssh/authorized_keys` : public keys allowed to SSH in as container root (one per line; see `docker/tizen-env/.ssh/authorized_keys.example`)

```sh
# from the repository root — standalone tizen-env. For the master php combination use D=compose/master_service (step 4)
D=compose/dev_env_service/tizen-env
cp "$D/.env-example" "$D/.env"      # point TIZEN_SSH_KEY · TIZEN_AUTHORIZED_KEYS at the real host paths
chmod 600 ~/.ssh/tizen_id_rsa ~/.ssh/tizen_authorized_keys
sudo chown root:root ~/.ssh/tizen_authorized_keys   # only authorized_keys is root-owned; the private key stays yours, mode 600
```

> ⚠️ **`TIZEN_AUTHORIZED_KEYS` must be root-owned with mode 600.** A bind mount shows the host file's owner (uid) inside the container, and sshd's `StrictModes` rejects a `/root/.ssh/authorized_keys` owned by anyone but root — leave it owned by you and `ssh -p 2221 root@127.0.0.1` fails with `Permission denied (publickey)`. `TIZEN_SSH_KEY` (`tizen_id_rsa`) can stay owned by you with mode 600 (container root reads it).
> Once it is root-owned you need `sudo` to add keys to it or change its permissions — re-running the block above verbatim fails at `chmod 600` with `Operation not permitted`.

- Compose refuses to start when either variable is empty. **If the path is wrong**, Docker creates a root-owned empty directory on the host, the container starts anyway and only SSH authentication fails — delete that directory, fix the path in `.env` and start again.
- To access the container directly for development, add a path to `volumes` in `docker-compose.yml`.

**2. Update the Tizen ssh config** — `docker/tizen-env/.ssh/config`

```shell
Host tizen review.tizen.org
Hostname review.tizen.org
IdentityFile ~/.ssh/id_rsa
# Update the User value below to the ID already registered on the Tizen official website.
# (ssh_config does not allow trailing comments, so keep comments on their own line)
User Tizen_Account_ID
Port 29418
# Add the line below when using a proxy, otherwise skip it.
# ProxyCommand nc -X5 -x <Proxy Address>:<Port> %h %p
```

**3. Configure git for Gerrit access** — update the git information in `docker/tizen-env/Dockerfile`.

```shell
git config --global user.name "ID"        # fill in ID
git config --global user.email "E-MAIL"   # fill in E-MAIL
```

**4. Run Docker Compose**

- Requirements: Docker Engine with the Compose plugin (`docker compose`). The legacy `docker-compose` (v1) command is not used (except by the bundled Harbor installer).
- **Tizen environment only** — after the `.env` in step 1, move there from the repository root and start it.

  ```sh
  cd compose/dev_env_service/tizen-env
  docker compose up -d --build
  ssh -p 2221 root@127.0.0.1    # SSH binds to 127.0.0.1:2221 by default — allow remote with TIZEN_SSH_BIND=0.0.0.0 in .env
  ```

- **Full service** (requires setting up [devspoon-web] and [devspoon-startup-web]) — tizenenv exists only in `docker-compose-php.yml`. It shares a container name (`tizenenv`) and port (2221) with the standalone tizen-env, so run only one of them.

  ```sh
  # from the repository root
  D=compose/master_service
  cp "$D/.env-example" "$D/.env"    # fill in the TIZEN_* paths and the PLANE_* · GITEA_* placeholders yourself
  bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
  cd "$D"
  docker compose -f docker-compose-php.yml up -d --build                    # php + plane · jenkins · gitea · tizenenv
  docker compose -f docker-compose-php.yml --profile redis up -d --build    # + redis
  docker compose -f docker-compose-php.yml --profile redis stop             # a stop without the profile leaves the redis container
  ```

  The php combination has only the `redis` profile (no celery).

  > ⚠️ **The first startup takes several minutes because of the Plane migration.** `plane-migrator` must finish before `plane-api` starts, and `plane-proxy` becomes ready after that; until then nginx may return 502. Plane and Gitea data live in named volumes, so there are no host folders (`pgdata/` and the like) to create — see [Plane · Gitea data volumes](#plane--gitea-data-volumes).
  >
  > ⚠️ **Changing `PLANE_DB_PASSWORD` later breaks the existing volume.** It is frozen as the PostgreSQL password at the moment `plane-pgdata` is created. Recreate `.env` with a different value and `plane-migrator` fails with `FATAL: password authentication failed for user "plane"`, and none of the app containers behind it start. Change the password inside the database too (`docker compose -f docker-compose-php.yml exec plane-db psql -U plane -c "ALTER USER plane PASSWORD '<new value>';"`), or discard the data and recreate the volume (`down -v`).

**5. Optional — full repository sync**

- Skip this if you only download packages or use an existing project. It needs **hundreds of GB** of local storage.
- It fetches every Tizen repository package locally.
- Run `repo init` with the shell scripts in `/root/repo-script` inside the container — there is one for everything and one for Raspberry Pi 3.

**6. Test the sample project**

- `/root/samples` holds projects for anchor5 and Raspberry Pi 3.
- It builds the `peripheral-io` package assuming you changed its code.
  - The result is `tizen-unified_iot-headed-3parts-armv7l-artik530.tar.gz` in `/Tizen-Work/mic-output`.

## Additional development item

- System integration between Jenkins, Gitea and tizen-env.
- Development of a Tizen image management solution.
  - The Tizen image management solution UI sample design

## Community

- **Personal Website** : Owner's personal website is devspoon.com

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com
  Personal site : devspoon.com

- Lim Tae-youn Member, Tizen Designer
- Kang Dong-hoon Member, Tizen Developer

### How to contribute to our project

- devspoon-startup-tizen code is hosted and maintained on [GitHub](https://github.com/devspoons/devspoon-startup-tizen).
  We plan to contribute to third-party tools in the official Tizen repository (https://review.tizen.org/git/).
- To contribute to devspoon-startup-tizen, see [GitHub](https://github.com/devspoons/devspoon-startup-tizen). It should include most of what you need to get started.

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
