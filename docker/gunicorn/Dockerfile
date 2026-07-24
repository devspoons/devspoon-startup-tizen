# syntax=docker/dockerfile:1.7
# =============================================================================
# gunicorn 앱 베이스 이미지 (multi-stage)
#
# - Stage 1 (builder): Python 3.14 소스 컴파일 + native build deps + pip 패키지
# - Stage 2 (runtime): builder 의 /usr/local 만 복사 + 런타임 디펜던시
#
# 효과
# - 최종 이미지에서 build-essential / pkg-config / 컴파일러 제거 → ~500MB 절감
# - python tarball 무결성을 SHA256 으로 검증 → 공급망 변조 방어
# - 동일 build context 를 compose 의 4개 서비스 (gunicorn-app, celery, celery-beat,
#   flower 의 대체용) 가 공유할 수 있도록 `image:` 태그로 1회 빌드 후 재사용
#   → docker-compose.yml 에서 gunicorn-app 만 build, 나머지는 image 참조
# =============================================================================


# -----------------------------------------------------------------------------
# Stage 1: builder
# -----------------------------------------------------------------------------
FROM ubuntu:24.04 AS builder

ARG PYTHON_VERSION=3.14.0
# Python tarball SHA256 — 공급망 변조 방어
#  - 값 출처: https://www.python.org/ftp/python/3.14.0/Python-3.14.0.tar.xz 를
#    HTTPS 로 다운로드 후 `sha256sum` 으로 산출 (2026-05-18 시점).
#  - 추가 검증 (선택): 같은 URL 의 .sigstore bundle 을 sigstore-python 으로
#    `python -m sigstore verify identity --cert-identity <release-mgr> ...` 실행 권장.
#    (본 Dockerfile 에는 미포함 — 사이드카 검증으로 분리하는 게 보편적.)
#  - 버전 bump 시 위 절차 재실행하여 값 갱신 필수.
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
        libmysqlclient-dev && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# 1.2. Python 소스 다운 → SHA256 검증 → 컴파일 (altinstall)
#      검증 실패 시 sha256sum -c 가 비0 종료 → 후속 RUN 중단 → 빌드 abort
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
# 1.3. Python 패키지 사전 설치 (native build 필요 항목 포함)
#      runtime 의 `uv sync --inexact` 가 본 site-packages 를 보존한다.
# ============================================================================
RUN pip install --no-cache-dir \
        sqlalchemy alembic pydantic \
        psycopg2-binary asyncpg \
        mysqlclient asyncmy \
        gunicorn "uvicorn[standard]" \
        fastapi uv poetry


# -----------------------------------------------------------------------------
# Stage 2: runtime
# -----------------------------------------------------------------------------
FROM ubuntu:24.04

ENV TZ=Asia/Seoul \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# ============================================================================
# 2.1. 런타임 도구 / 타임존 / 운영 라이브러리
#  - build-essential / pkg-config 미포함 (builder 전용)
#  - *-dev 패키지는 native .so 가 링크하는 런타임 라이브러리 의존성 확보를 위해 유지
#    (mysqlclient.so → libmysqlclient, psycopg2.so → libpq 등)
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends apt-utils && \
    apt-get install -y --no-install-recommends \
        tzdata ca-certificates \
        curl wget git tar gnupg2 lsb-release lz4 zstd vim \
        zlib1g libncurses6 libgdbm6t64 libnss3 libssl3 \
        libreadline8t64 libffi8 libsqlite3-0 \
        libbz2-1.0 liblzma5 libnsl2 libuuid1 \
        libmysqlclient21 && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# 2.2. builder 의 Python 트리 통째 복사
#      /usr/local/{bin,lib,include} 가 한꺼번에 들어와 시스템 python3.12 와
#      공존(altinstall) → /usr/bin 의 심볼릭 링크만 3.14 로 정정.
# ============================================================================
COPY --from=builder /usr/local /usr/local
RUN ldconfig && \
    rm -f /usr/bin/python /usr/bin/python3 && \
    ln -s /usr/local/bin/python3.14 /usr/bin/python && \
    ln -s /usr/local/bin/python3.14 /usr/bin/python3 && \
    ln -s /usr/local/bin/pip3.14 /usr/bin/pip && \
    ln -s /usr/local/bin/pip3.14 /usr/bin/pip3

# ============================================================================
# 2.3. uv "no-venv / 시스템 Python" 모드 ENV
#      `uv sync --inexact` 가 /usr/local/lib/python3.14/site-packages 에 직접 설치하여
#       builder 단계가 깐 패키지(fastapi/sqlalchemy/wheel 등) 를 보존한다.
#      ★ UV_PYTHON 명시 — 미지정 시 시스템 python3.12 가 선택되어 shebang 불일치 발생.
# ============================================================================
ENV UV_PROJECT_ENVIRONMENT=/usr/local \
    UV_PYTHON=/usr/local/bin/python3.14 \
    UV_PYTHON_PREFERENCE=only-system \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_NO_CACHE=1

# ============================================================================
# 2.4. cron + logrotate (운영 컨테이너의 로그 회전 인프라)
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
#   - 컨테이너 PID1 은 gunicorn/uvicorn/celery 가 점유 → cron 데몬은 entrypoint 가
#     백그라운드 기동 (entrypoint-with-cron.sh)
#   - 일일 02:00 logrotate 실행 — /run/logrotate.d/* (entrypoint sanitize 사본) 처리.
#     Debian 기본 /etc/cron.daily/logrotate 는 /etc/logrotate.conf 만 보고
#     /etc/logrotate.d/* (WSL 0777 mount) 를 직접 처리하므로 sanitize 효과가
#     없음 — 별도 entry 가 필요.
# ============================================================================
RUN ( crontab -l 2>/dev/null; \
      echo "0 2 * * * /usr/local/bin/logrotate-all.sh >> /log/gunicorn/logrotate.log 2>&1" \
    ) | crontab - \
 && printf '#!/bin/sh\nfor f in /run/logrotate.d/*; do [ -f "$f" ] && /usr/sbin/logrotate -s /var/lib/logrotate/status "$f"; done\n' > /usr/local/bin/logrotate-all.sh \
 && chmod +x /usr/local/bin/logrotate-all.sh

# ============================================================================
# 2.6. ENTRYPOINT — start cron then exec compose `command:`
# ============================================================================
COPY entrypoint-with-cron.sh /usr/local/bin/entrypoint-with-cron
RUN chmod +x /usr/local/bin/entrypoint-with-cron
ENTRYPOINT ["/usr/local/bin/entrypoint-with-cron"]
