from datetime import datetime

# 바인딩 주소 및 포트
bind = "0.0.0.0:8000"

worker_class = "sync"

# Gunicorn 워커 설정
# workers = multiprocessing.cpu_count() * 2 + 1
# 쿼드코어 CPU + 4GB RAM 환경에서 메모리 고려한 워커 수
workers = 4

# Worker별 스레드 (sync worker 사용 시)
threads = 2  # 워커당 2개 스레드로 동시성 향상

worker_connections = 1000  # 최대 동시 연결 수

# 프로세스 관리 설정
# pidfile = '/tmp/gunicorn.pid' # 백그라운드에서 pid 파일 생성 (데몬 모드와 함께 사용)
daemon = False  # 데몬 모드 설정 (True일 경우 백그라운드 실행)

# ASGI, WSGI 애플리케이션 경로 설정
wsgi_app = "config.wsgi:application"

# 타임아웃 설정
# 50 req/s 트래픽에서 적절한 타임아웃
timeout = 60  # 타임아웃 (초) - API 응답 시간에 맞게 조정
keepalive = 5   # Keepalive 타임아웃 (초) - 연결 재사용 효율 향상
graceful_timeout = 30  # Graceful shutdown 타임아웃 (초)

# 프로세스 리소스 관리
# 메모리 누수 방지를 위한 워커 재시작 설정
max_requests = 1000  # 워커당 처리할 최대 요청 수
max_requests_jitter = 100   # 모든 워커가 동시에 재시작되는 것 방지

# 프로세스 재시작 옵션
preload_app = True  # 메모리 절약 (Django 앱 미리 로드)
reload = False # 프로덕션 환경에서 reload=True는 절대 사용 불가

# 로깅 설정
# Whether to send Django output to the error log 
loglevel = "info"  # 로그 레벨
capture_output = False
enable_stdio_inheritance = True  # 상위 프로세스 stdio 상속
accesslog = f"/log/gunicorn/access_{datetime.now().strftime('%Y-%m-%d_%H')}.log"
errorlog = f"/log/gunicorn/error_{datetime.now().strftime('%Y-%m-%d_%H')}.log"

# 상세 로그 포맷
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s %(p)s'

# 워커 프로세스 이름 설정 (모니터링 시 유용)
proc_name = "fastapi_gunicorn"

# statsd_host = 'localhost:8125' # 성능 분석을 위해 구니콘의 내부 통계를 수집할 경로 설정, StatsD 서버 연동 시 주석 해제

# ==========================================
# 성능 최적화
# ==========================================
# - 최대 2048개의 연결이 Accept Queue에서 대기 가능
# - 동시에 많은 연결 요청이 들어와도 2048개까지는 거부되지 않음
# - 실제 적용값 = min(2048, 시스템 somaxconn)
backlog = 2048 

# 임시 파일 디렉토리 (업로드 처리 시 사용)
worker_tmp_dir = "/dev/shm"  # RAM 기반 tmpfs 사용으로 I/O 성능 향상

# ==========================================
# 보안 설정
# ==========================================
# 요청 크기 제한 (DoS 방지) - Nginx 설정 의존
# limit_request_line = 4094
# limit_request_fields = 100
# limit_request_field_size = 8190