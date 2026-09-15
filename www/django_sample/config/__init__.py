# Django 시작 시 Celery 앱을 로드해 @shared_task 가 항상 등록되도록 한다.
# celery 가 설치되지 않은 환경(--extra celery 없이 기동된 컨테이너 등)에서도 Django 부팅이
# 막히지 않도록 import 실패를 흡수한다. celery 가 있으면 정상적으로 celery_app 을 노출한다.
try:
    from .celery import app as celery_app

    __all__ = ("celery_app",)
except ImportError:
    celery_app = None
    __all__ = ()
