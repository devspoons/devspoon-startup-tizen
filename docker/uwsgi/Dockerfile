# syntax=docker/dockerfile:1.7
# =============================================================================
# uwsgi 앱 베이스 이미지 (multi-stage)
#
# - 구조는 docker/gunicorn/Dockerfile 과 동일하며, builder 단계에서 native
#   확장(uwsgi, mysqlclient, psycopg2 등) 을 사전 컴파일하고 runtime 단계는
#   build-essential 없이 실행 라이브러리만 갖춘다.
# - Python tarball SHA256 검증으로 공급망 변조 차단.
# - compose 에서 동일 이미지를 uwsgi-app / celery / celery-beat 가 공유하도록
#   `image: devspoon-uwsgi-app:latest` 태그 부여 후 build 는 1회만 수행한다.
# =============================================================================


# -----------------------------------------------------------------------------
# Stage 0: lock — 빈 기본값, 추가 빌드 컨텍스트 `lock` 이 덮어씀 (docker/gunicorn/Dockerfile 과 동일)
# -----------------------------------------------------------------------------
FROM scratch AS lock

# -----------------------------------------------------------------------------
# Stage 1: builder
# -----------------------------------------------------------------------------
FROM ubuntu:24.04 AS builder

ARG PYTHON_VERSION=3.14.0
# Python tarball SHA256 — 공급망 변조 방어 (자세한 갱신 절차는 gunicorn Dockerfile 참조)
ARG PYTHON_SHA256=2299dae542d395ce3883aca00d3c910307cd68e0b2f7336098c8e7b7eee9f3e9

ENV TZ=Asia/Seoul \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# ============================================================================
# 1.1. 빌드 디펜던시 (build-essential / *-dev) — 최종 이미지에는 미포함
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl wget tar xz-utils gnupg \
        build-essential pkg-config \
        zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev \
        libreadline-dev libffi-dev libsqlite3-dev \
        libbz2-dev liblzma-dev \
        libmysqlclient-dev libpcre3-dev libxml2-dev && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# 1.2. Python 소스 다운 → SHA256 검증 → altinstall
# ============================================================================
RUN set -eux; \
    cd /usr/src && \
    wget -q "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz" && \
    echo "${PYTHON_SHA256}  Python-${PYTHON_VERSION}.tar.xz" | sha256sum -c - && \
    tar -xf "Python-${PYTHON_VERSION}.tar.xz" && \
    cd "Python-${PYTHON_VERSION}" && \
    ./configure --with-ensurepip=install && \
    make -j"$(nproc)" altinstall && \
    cd / && rm -rf "/usr/src/Python-${PYTHON_VERSION}" "/usr/src/Python-${PYTHON_VERSION}.tar.xz" && \
    ln -sf /usr/local/bin/python3.14 /usr/local/bin/python && \
    ln -sf /usr/local/bin/python3.14 /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip3 && \
    python -m pip install --no-cache-dir --upgrade pip wheel

# ============================================================================
# 1.3. Python 패키지 사전 설치 (uwsgi 포함 — native build 필요)
# ============================================================================
# 사전설치 = www/django_sample/uv.lock 해석 결과 (정책은 docker/gunicorn/Dockerfile 1.3 과 동일, s6 6.19).
# extras = uwsgi 스택 compose `uv sync --extra` + 기존 사전설치(gunicorn·uvicorn) 유지.
COPY --from=lock pyproject.toml uv.lock /tmp/lock/
RUN pip install --no-cache-dir uv && \
    cd /tmp/lock && uv export --frozen --no-hashes --no-header --no-annotate -o requirements.txt \
        --extra gunicorn --extra uvicorn --extra uwsgi --extra celery && \
    pip install --no-cache-dir -r /tmp/lock/requirements.txt && \
    pip install --no-cache-dir -c /tmp/lock/requirements.txt \
        sqlalchemy alembic pydantic \
        psycopg2-binary asyncpg \
        mysqlclient asyncmy \
        poetry && \
    rm -rf /tmp/lock


# -----------------------------------------------------------------------------
# Stage 2: runtime
# -----------------------------------------------------------------------------
FROM ubuntu:24.04

ENV TZ=Asia/Seoul \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# ============================================================================
# 2.1. 런타임 도구 / 타임존 / 운영 라이브러리 (build-essential 미포함)
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends apt-utils && \
    apt-get install -y --no-install-recommends \
        tzdata ca-certificates \
        curl wget git tar gnupg2 lsb-release lz4 zstd vim \
        zlib1g libncurses6 libgdbm6t64 libnss3 libssl3 \
        libreadline8t64 libffi8 libsqlite3-0 \
        libbz2-1.0 liblzma5 libnsl2 libuuid1 \
        libmysqlclient21 libpcre3 libxml2 && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# 2.2. builder 의 Python 트리 복사
# ============================================================================
COPY --from=builder /usr/local /usr/local
RUN ldconfig && \
    rm -f /usr/bin/python /usr/bin/python3 && \
    ln -s /usr/local/bin/python3.14 /usr/bin/python && \
    ln -s /usr/local/bin/python3.14 /usr/bin/python3 && \
    ln -s /usr/local/bin/pip3.14 /usr/bin/pip && \
    ln -s /usr/local/bin/pip3.14 /usr/bin/pip3

# ============================================================================
# 2.3. uv "no-venv / 시스템 Python" 모드 ENV (gunicorn Dockerfile 와 동일 정책)
# ============================================================================
ENV UV_PROJECT_ENVIRONMENT=/usr/local \
    UV_PYTHON=/usr/local/bin/python3.14 \
    UV_PYTHON_PREFERENCE=only-system \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_NO_CACHE=1

# ============================================================================
# 2.4. cron + logrotate
#  - 백업 도구(percona-xtrabackup / pgbackrest) 설치 블록 제거:
#    본 프로젝트는 외부 DB(MySQL/PostgreSQL)를 쓰지 않고(앱은 sqlite3) 이 도구를
#    호출하는 곳도 없음. 필요해지면 backup 전용 사이드카 이미지로 분리할 것.
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cron logrotate && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# 2.5. Cron + logrotate 부트스트랩
#   - uwsgi 본체 로그는 uwsgi.ini 의 log-maxsize 로 네이티브 회전 (logrotate 마운트 불필요)
#   - celery / celery-beat 는 Python logging — 호스트 마운트된 /etc/logrotate.d/uwsgi-celery* 회전 대상
#   - 일일 02:00 실행, cron 데몬은 entrypoint-with-cron.sh 가 기동
# ============================================================================
RUN ( crontab -l 2>/dev/null; \
      echo "0 2 * * * /usr/local/bin/logrotate-all.sh >> /log/uwsgi/logrotate.log 2>&1" \
    ) | crontab - \
 && printf '#!/bin/sh\nfor f in /run/logrotate.d/*; do [ -f "$f" ] && /usr/sbin/logrotate -s /var/lib/logrotate/status "$f"; done\n' > /usr/local/bin/logrotate-all.sh \
 && chmod +x /usr/local/bin/logrotate-all.sh

# ============================================================================
# 2.6. ENTRYPOINT
# ============================================================================
COPY entrypoint-with-cron.sh /usr/local/bin/entrypoint-with-cron
RUN chmod +x /usr/local/bin/entrypoint-with-cron
ENTRYPOINT ["/usr/local/bin/entrypoint-with-cron"]
