"""
샘플 Celery 태스크 — celery 프로파일 동작 검증용.
"""
from celery import shared_task


@shared_task
def add(x, y):
    return x + y


@shared_task
def ping():
    return "pong"
