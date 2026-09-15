"""
Uvicorn (UvicornWorker via Gunicorn) Configuration
=====================================================
환경: Production Level
서버 사양: 8 core CPU / 8 GB RAM
배포 정책: 수동 stop/start (무중단 미고려) → preload_app=True 로 메모리 절감 채택
백엔드: FastAPI / Django ASGI (UvicornWorker)
프록시: Nginx (SSL/TLS, DDoS, Rate Limiting 처리)
=====================================================
※ 본 파일은 gunicorn.conf.py 의 ASGI(UvicornWorker) 전용 사본이다.
   - 경로 분리: /uvicorn 마운트, /uvicorn/uvicorn.conf.py 사용
   - 비동기 워커는 단일 이벤트 루프로 다수 동시 요청 처리 → 워커 수는 코어 수 매칭
=====================================================
"""

import os

# ============================================================================
# 네트워크 바인딩
# ============================================================================
bind = "0.0.0.0:8000"

# ============================================================================
# Worker 프로세스
# ============================================================================
# 산정:
#   - 비동기 워커는 단일 프로세스 내 다수 동시 요청 처리(asyncio + uvloop)
#   - 일반적으로 1 worker / core 가 최적: workers = 8
#   - UvicornWorker 메모리: 400-700MB / worker (FastAPI + 라이브러리)
#   - 8 워커 × 600MB ≈ 4.8GB (시스템/celery 등 포함 시 6GB 헤드룸 내)
workers = 8

# ASGI 비동기 워커 (uvloop + httptools 기반 — uvicorn[standard] 필요)
worker_class = "uvicorn.workers.UvicornWorker"

# UvicornWorker 는 worker_connections 무시 (asyncio 이벤트 루프 사용)
# worker_connections = 1000

# ============================================================================
# 프로세스 관리
# ============================================================================
daemon = False

# ASGI 엔트리포인트 (Django: config.asgi, FastAPI: main:app 등 프로젝트에 맞춰 변경)
# 환경변수 ASGI_APP 로 오버라이드 가능 — 미설정 시 Django 기본값 유지(기존 동작 무손상).
#   예) FastAPI: 컨테이너 env 에 ASGI_APP=app.main:app
wsgi_app = os.environ.get("ASGI_APP", "config.asgi:application")

# ============================================================================
# 타임아웃
# ============================================================================
# 비동기 API 평균 응답 1-3초 가정. 긴 작업은 background task 또는 celery 로 분리
timeout = 30

# Nginx 가 keepalive 흡수하므로 짧게 (Nginx keepalive_timeout 보다 작게)
keepalive = 2

# 수동 stop 배포 시 진행 중인 요청 graceful drain 시간
graceful_timeout = 30

# ============================================================================
# 메모리 누수 방어
# ============================================================================
# 비동기 워커는 메모리 누적이 sync 대비 빠를 수 있어 보수적 운용
max_requests = 2000
max_requests_jitter = 200

# ============================================================================
# 애플리케이션 로딩
# ============================================================================
# 수동 stop/start 배포 → preload_app=True
# - UvicornWorker + preload 조합 시 fork 후 uvloop 재초기화 (uvicorn[standard] 0.20+ 지원)
# - 무중단 reload (kill -HUP) 미사용 가정
preload_app = True

reload = False

# ============================================================================
# 로깅 (모든 로그는 /log/uvicorn/ 식별 폴더에 일원화)
# ============================================================================
loglevel = "info"
capture_output = False

accesslog = "/log/uvicorn/uvicorn_access.log"
errorlog = "/log/uvicorn/uvicorn_error.log"

access_log_format = (
    '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s %(p)s'
)

proc_name = "fastapi_uvicorn"

# ============================================================================
# TCP backlog
# ============================================================================
backlog = 2048

# 비동기 워커는 디스크 I/O 거의 없음 → /dev/shm 미사용
worker_tmp_dir = None


# ==========================================
# 권한 강하 (privilege drop) — uwsgi/php-fpm/gunicorn 스택과 동일하게 워커를 www-data 로 실행.
# 컨테이너는 root 로 기동(uv sync 등)되고, gunicorn arbiter(master)는 root 를 유지하되
# UvicornWorker 를 fork 하며 www-data(uid 33) 로 setuid 한다. (root 워커 회피)
# 전제: /www 앱 소스는 www-data 가 읽기 가능해야 하고(배포 시 644/755), compose command 의
#       `chown -R www-data:www-data /www/${PROJECT_DIR}` 가 SQLite db 쓰기 권한을 맞춘다.
# ==========================================
user = "www-data"
group = "www-data"

"""
운영 체크리스트:
1. logrotate (script/logrotate/uvicorn/) 가 /etc/logrotate.d/uvicorn 에 마운트되어
   /log/uvicorn/*.log 를 daily 로테이션
2. UvicornWorker 는 sync I/O blocking 코드(파일/CPU 집약 작업)에 취약 → 반드시 asyncio 친화 라이브러리 사용
3. 동시성 부족 시: workers 늘리기 전에 asyncio.Semaphore / connection pool / cache 점검
4. 부하 테스트: wrk -t8 -c200 -d60s http://...
"""
