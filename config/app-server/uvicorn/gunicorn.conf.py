import multiprocessing
from datetime import datetime
import os

# 바인딩 주소 및 포트
bind = "0.0.0.0:8000"

# Gunicorn 워커 설정
# workers = multiprocessing.cpu_count() * 2 + 1
workers = 4
worker_class = "uvicorn.workers.UvicornWorker"  # Uvicorn 워커 클래스 사용
# worker_connections = 1000  # 최대 동시 연결 수

# 프로세스 관리 설정
# pidfile = '/tmp/gunicorn.pid' # 백그라운드에서 pid 파일 생성 (데몬 모드와 함께 사용)
daemon = False  # 데몬 모드 설정 (True일 경우 백그라운드 실행)

# ASGI, WSGI 애플리케이션 경로 설정
wsgi_app = "config.asgi:application"

# 타임아웃 설정
timeout = 30  # 타임아웃 설정 (초)
keepalive = 2  # Keepalive 타임아웃 (초)
graceful_timeout = 30  # Graceful 타임아웃 설정 (초)

# 프로세스 리소스 관리
max_requests = 1000  # 워커당 처리할 최대 요청 수
max_requests_jitter = 50  # 최대 요청 흩어짐 설정

# 프로세스 재시작 옵션
preload_app = False  # 앱 로딩 지연 설정
reload = True

# 로깅 설정
# Whether to send Django output to the error log 
capture_output = False
loglevel = "info"  # 로그 레벨
accesslog = f"/log/uvicorn/access_{datetime.now().strftime('%Y-%m-%d_%H')}.log"
errorlog = f"/log/uvicorn/error_{datetime.now().strftime('%Y-%m-%d_%H')}.log"
# access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"' # 로그 형식 설정 (액세스 로그의 형식을 지정)

# statsd_host = 'localhost:8125' # 성능 분석을 위해 구니콘의 내부 통계를 수집할 경로 설정
