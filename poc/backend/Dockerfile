# 도박중독 DTx 백엔드 — 운영 이미지 (Django + Gunicorn)
FROM python:3.11-slim AS base

# 파이썬 런타임 설정
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

WORKDIR /app

# 시스템 의존성 (psycopg 빌드/런타임 최소)
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# 의존성 먼저 설치 (레이어 캐시)
COPY requirements.txt requirements-prod.txt ./
RUN pip install -r requirements-prod.txt

# 앱 소스 복사
COPY . .

# 정적파일 수집 (admin/DRF 등) — 더미 키로 빌드 타임 collectstatic
RUN DJANGO_SECRET_KEY=build-time-dummy DJANGO_DEBUG=False \
    python manage.py collectstatic --noinput

# 비루트 사용자로 실행
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# 컨테이너 헬스체크 (노출 미디어 엔드포인트)
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT}/api/v1/exposure-media" || exit 1

ENTRYPOINT ["./entrypoint.sh"]
