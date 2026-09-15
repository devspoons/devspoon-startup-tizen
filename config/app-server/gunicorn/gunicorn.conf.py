"""
Gunicorn Configuration
=====================================================
환경: Production Level
서버 사양: 쿼드코어 CPU, 4GB RAM, ~50 req/s
백엔드: Django
프록시: Nginx (SSL/TLS, DDoS, Rate Limiting 처리)
=====================================================
"""

import os

# ============================================================================
# 네트워크 바인딩 설정
# ============================================================================
# 바인딩 주소 및 포트
# 역할: Gunicorn이 수신할 네트워크 주소
# 0.0.0.0:8000 - 모든 네트워크 인터페이스에서 수신 (Docker/컨테이너 환경)
# 127.0.0.1:8000 - 로컬 전용 (Nginx와 동일 호스트, 보안 강화)
# Nginx 연동: Nginx가 외부 트래픽 처리, Gunicorn은 내부 전용
bind = "0.0.0.0:8000"

# ============================================================================
# Worker 프로세스 설정
# ============================================================================
# Worker 수
# 역할: 동시 요청 처리를 위한 프로세스 수
# 공식: I/O 집약적 작업 = (CPU 코어 * 2) + 1
# 계산: 쿼드코어(4) → 9개 권장, 하지만 4GB RAM 제약으로 4개 설정
#       각 워커 메모리: 200-500MB
#       4 워커 × 500MB = 2GB (시스템 예비 2GB 확보)
# 성능: ~50 req/s는 4개 워커로 충분 (워커당 ~12.5 req/s)
# 환경 변수: GUNICORN_WORKERS=6 으로 오버라이드 가능
# workers = multiprocessing.cpu_count() * 2 + 1
workers = 4

# Worker별 스레드 (sync worker 사용 시)
threads = 2  # 워커당 2개 스레드로 동시성 향상

worker_connections = 1000  # 최대 동시 연결 수

worker_class = "sync"

# ============================================================================
# 프로세스 관리 설정
# ============================================================================
# 데몬 모드
# 역할: 백그라운드 실행 여부
# False: systemd/Docker가 프로세스 관리 (현대적 방식)
# True: 수동 관리 시 사용 (pidfile 필수)
daemon = False  # 데몬 모드 설정 (True일 경우 백그라운드 실행)

# PID 파일 (주석 처리 - systemd/Docker 사용 시 불필요)
# 역할: Master 프로세스 ID 저장
# 수동 관리 시 활성화: pidfile = '/var/run/gunicorn/gunicorn.pid'
# pidfile = '/tmp/gunicorn.pid'

# ASGI, WSGI 애플리케이션 경로 설정
# 환경변수 WSGI_APP 로 오버라이드 — 미설정 시 Django 기본값. 예) flask_sample: WSGI_APP=app.main:app
wsgi_app = os.environ.get("WSGI_APP", "config.wsgi:application")

# ============================================================================
# 타임아웃 설정
# ============================================================================
# Worker 타임아웃
# 역할: Worker가 요청 처리 최대 허용 시간 (초)
# 동작: 타임아웃 초과 시 Worker 강제 종료 후 재시작
# 계산: FastAPI REST API 평균 응답 1-5초
#       파일 업로드 고려 (100MB / 10Mbps = 80초)
# Nginx 연동: proxy_read_timeout(60s)보다 짧거나 같게 설정
# 50 req/s 트래픽에서 적절한 타임아웃
timeout = 60  # 타임아웃 (초) - API 응답 시간에 맞게 조정

# Keep-Alive 타임아웃
# 역할: HTTP Keep-Alive 연결 유지 시간 (초)
# 동작: 연결 재사용으로 핸드셰이크 오버헤드 감소
# Nginx 연동: Nginx keepalive_timeout(30s)보다 짧게 설정
#            Nginx가 먼저 종료하도록 하여 리소스 효율화
keepalive = 5  # Keepalive 타임아웃 (초) - 연결 재사용 효율 향상

# Graceful 종료 타임아웃
# 역할: Worker 재시작/종료 시 진행 중인 요청 완료 대기 시간 (초)
# 동작: SIGTERM 수신 후 새 요청 거부, 기존 요청 처리
#       타임아웃 초과 시 SIGKILL로 강제 종료
# 기대 효과: Graceful reload로 무중단 배포
#           kill -HUP <pid> 또는 systemctl reload gunicorn
# timeout과 동일하게 설정
graceful_timeout = 30  # Graceful shutdown 타임아웃 (초)

# ============================================================================
# 프로세스 리소스 관리 (메모리 누수 방지)
# ============================================================================
# Worker 최대 요청 수
# 역할: Worker가 처리할 최대 요청 후 자동 재시작
# 목적: 메모리 누수 방어, 장기 운영 안정성
# 동작: max_requests 도달 시 Worker graceful 종료 후 재시작
# 계산: ~50 req/s 기준
#       1000으로 설정 시 워커당 20초마다 재시작 (1000/50)
#       메모리 누수 우려 시 유지, 안정적이면 5000-10000 증가 가능
# 모니터링: htop으로 워커 메모리 사용량 추이 확인
max_requests = 1000  # 워커당 처리할 최대 요청 수

# 최대 요청 수 Jitter
# 역할: max_requests에 랜덤성 추가
# 목적: 모든 Worker가 동시에 재시작하는 것 방지
# 동작: 실제 재시작 = max_requests ± random(0, jitter)
# 기대 효과: 재시작 부하 분산, 서비스 연속성 보장
# 권장: max_requests의 5-10%
max_requests_jitter = 100  # 모든 워커가 동시에 재시작되는 것 방지

# ============================================================================
# 애플리케이션 로딩 설정
# ============================================================================
# 애플리케이션 사전 로딩
# 역할: Worker fork 전 앱 로딩 방식 결정
# False: 각 Worker가 독립적으로 앱 로딩
#        - 장점: Graceful reload 가능 (무중단 배포)
#        - 단점: 메모리 중복 사용 (Worker 수만큼)
# True: Master 프로세스에서 앱 로딩 후 Worker fork
#       - 장점: 메모리 20-40% 절감 (Copy-on-Write)
#       - 단점: reload 시 전체 재시작 필요 (다운타임)
# 프로덕션 권장: False (무중단 배포 우선)
preload_app = True  # 메모리 절약 (Django 앱 미리 로드)

# 코드 변경 감지 자동 재시작
# 역할: 파일 변경 시 Worker 자동 재시작
# 성능 영향: CPU 5-10% 오버헤드, 메모리 50-100MB 추가
# 보안: 예기치 않은 재시작으로 서비스 불안정
# **프로덕션에서는 반드시 False**
# 개발 환경에서만 True 사용
# 배포: CI/CD 파이프라인에서 명시적 재시작
reload = False

# 로깅 설정
# Whether to send Django output to the error log
loglevel = "info"  # 로그 레벨

# 애플리케이션 출력 캡처
# 역할: FastAPI의 print(), logging을 Gunicorn 로그로 리다이렉트
# False: 앱 로거가 독립적으로 관리 (권장)
# True: stdout/stderr를 errorlog로 통합
# FastAPI 권장: False (자체 로거 사용)
capture_output = False

enable_stdio_inheritance = True  # 상위 프로세스 stdio 상속
accesslog = "/log/gunicorn/gunicorn_access.log"
errorlog = "/log/gunicorn/gunicorn_error.log"

# 상세 로그 포맷
access_log_format = (
    '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s %(p)s'
)

# 워커 프로세스 이름 설정 (모니터링 시 유용)
proc_name = "fastapi_gunicorn"

# ==========================================
# 성능 최적화
# ==========================================
# - 최대 2048개의 연결이 Accept Queue에서 대기 가능
# - 동시에 많은 연결 요청이 들어와도 2048개까지는 거부되지 않음
# - 실제 적용값 = min(2048, 시스템 somaxconn)
# 낮은 트래픽 (기본값 충분)
# backlog = 2048  # 기본값 사용
# workers = 4
#
# 높은 트래픽 (증가 필요)
# backlog = 4096
# workers = 8
# OS 설정도 함께 조정 필요
# /etc/sysctl.conf
# net.core.somaxconn = 4096
#
# 증가해야 할 때:
# ss -lnt 명령으로 Send-Q가 계속 가득 찬 경우
# ss -lnt | grep :8000
# 순간적인 트래픽 급증이 예상되는 경우
# connection refused 에러가 자주 발생하는 경우
backlog = 2048

# 임시 파일 디렉토리 (업로드 처리 시 사용)
#  재부팅 시 자동 삭제
# Gunicorn 기본값
# worker_tmp_dir = None  # /tmp 디렉토리 사용 (디스크 기반)
# 사용하는 경우 (권장):
# 파일 업로드가 많은 서비스
# 큰 요청/응답 처리
# 충분한 RAM이 있는 경우
# RAM이 부족한 경우
# worker_tmp_dir = "/tmp"  # 디스크 사용
# 파일 업로드/다운로드가 거의 없는 경우
# worker_tmp_dir = None  # 기본값 사용
# Docker 사용시 고려 필요
# shm_size: '2gb'  # /dev/shm 크기 증가
#    volumes:
#      - /dev/shm:/dev/shm  # 호스트 공유 (선택)

# worker_tmp_dir = "/dev/shm"  # RAM 기반 tmpfs 사용으로 I/O 성능 향상
worker_tmp_dir = None


# ==========================================
# 권한 강하 (privilege drop) — uwsgi/php-fpm 와 동일하게 워커를 www-data 로 실행 (최소권한).
# 컨테이너는 root 로 기동(uv sync 등)되고, gunicorn arbiter(master)는 root 를 유지하되
# 워커를 fork 하며 www-data(uid 33) 로 setuid 한다. (root 워커 회피)
# 전제: /www 앱 소스는 www-data 가 읽기 가능해야 하고(배포 시 644/755), compose command 의
#       `chown -R www-data:www-data /www/${PROJECT_DIR}` 가 SQLite db 쓰기 권한을 맞춘다.
# ==========================================
user = "www-data"
group = "www-data"


"""
배포 전 체크리스트:

[권장]
1. 로그 로테이션 설정 (logrotate)
2. 헬스체크 엔드포인트 구현 (/health)
3. 성능 테스트 (wrk, locust)

성능 모니터링:
    # 프로세스 확인
    ps aux | grep gunicorn

    # 리소스 사용량
    htop -p $(pgrep -d',' gunicorn)

    # 로그 실시간 확인
    tail -f /log/uvicorn/access_*.log
    tail -f /log/uvicorn/error_*.log

설정 최적화 가이드:
    - workers: CPU 사용률 80% 이하 유지
    - timeout: 응답 시간 + 여유분 (평균 * 2)
    - max_requests: 메모리 누수 없으면 5000-10000으로 증가
    - keepalive: Nginx keepalive_timeout보다 짧게
"""
