import multiprocessing
from datetime import datetime
import os

bind = "0.0.0.0:8000"
# workers = multiprocessing.cpu_count() * 2 + 1
workers = 4
wsgi_app = "config.wsgi:application"
reload = True
accesslog = f"/log/gunicorn/access_{datetime.now().strftime('%Y-%m-%d_%H')}.log"
errorlog = f"/log/gunicorn/error_{datetime.now().strftime('%Y-%m-%d_%H')}.log"
loglevel = "info"
