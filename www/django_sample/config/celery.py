"""
Celery 앱 정의 — devspoon-web 의 celery / celery-beat / flower 프로파일에서 사용.
compose 의 command 는 `celery -A config worker ...` / `celery -A config beat ...` 로
본 모듈의 `app` (== celery_app) 을 참조한다.
브로커는 settings.CELERY_BROKER_URL (env CELERY_BROKER_URL) 로 주입된다.
"""
import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

app = Celery("config")

# settings.py 의 CELERY_ 접두 변수를 celery config 로 로드 (namespace="CELERY")
app.config_from_object("django.conf:settings", namespace="CELERY")

# 각 앱의 tasks.py 자동 등록 (main/tasks.py 등)
app.autodiscover_tasks()


@app.task(bind=True, ignore_result=True)
def debug_task(self):
    """worker 동작 검증용 샘플 태스크."""
    print(f"Request: {self.request!r}")
