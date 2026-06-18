#!/usr/bin/env bash
# 컨테이너 시작: DB 마이그레이션 → 시드 → Gunicorn 기동
set -euo pipefail

echo "[entrypoint] 마이그레이션 적용..."
python manage.py migrate --noinput

# 시드는 멱등(이미 있으면 skip). 실패해도 기동은 계속.
echo "[entrypoint] 시드 데이터 확인..."
python manage.py seed || echo "[entrypoint] 시드 건너뜀"

echo "[entrypoint] Gunicorn 기동 (port ${PORT:-8000})"
exec gunicorn config.wsgi:application \
    --bind "0.0.0.0:${PORT:-8000}" \
    --workers "${GUNICORN_WORKERS:-3}" \
    --timeout "${GUNICORN_TIMEOUT:-60}" \
    --access-logfile - \
    --error-logfile -
