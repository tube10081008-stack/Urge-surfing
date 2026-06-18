#!/usr/bin/env bash
# DTx PoC 개발 환경 셋업 — 세션 시작 시 백엔드를 바로 실행 가능한 상태로 준비.
# 컨테이너는 세션마다 새로 생성되므로 멱등(idempotent)하게 작성.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/poc/backend"

echo "[setup] 백엔드 환경 준비: $BACKEND"
cd "$BACKEND"

# 1) 가상환경 (없으면 생성)
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

# 2) 의존성 설치
pip install -q --disable-pip-version-check -r requirements.txt

# 3) DB 마이그레이션 + 시드 (멱등)
python manage.py migrate --noinput
python manage.py seed || true

# 4) 헬스 체크
python manage.py check

echo "[setup] 완료 ✅  백엔드 실행:  cd poc/backend && source .venv/bin/activate && python manage.py runserver"
echo "[setup] 참고: Flutter 앱(poc/app)은 이 환경에 flutter SDK가 없으면 코드 편집만 가능."
