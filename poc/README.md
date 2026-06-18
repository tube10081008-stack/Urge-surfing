# 🛟 DTx PoC (P0) — Flutter 앱 + Django REST 백엔드

> **P0 목표:** 노출(Exposure) 1종 → 충동 파도타기(타이머·파도·호흡) → VAS 전/후 기록 → 결과/대시보드.
> **제외:** App Blocker, 인증/RBAC, TimescaleDB (운영 전환 시 승격). PoC는 **빠르게 돌려보는 것**이 목적.

```
poc/
├── API-CONTRACT.md     ← Flutter ↔ DRF 공유 계약 (SSOT)
├── backend/            ← Django REST Framework (SQLite, 무인증)
└── app/                ← Flutter (Riverpod) — 충동 파도타기 UI
```

## ▶ 실행 순서

### 1) 백엔드
```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed          # 노출 자극 시드
python manage.py runserver     # http://localhost:8000
```

### 2) 앱
```bash
cd app
flutter pub get
# lib/api/api_client.dart 의 baseUrl 확인 (에뮬레이터는 10.0.2.2, iOS 시뮬은 localhost)
flutter run
```

## 흐름
홈 → 사전 VAS → 노출(플레이스홀더) → 충동 파도타기(3분, 파도 잔잔해짐 + 4-7-8 호흡) → 사후 VAS → 결과 전송 → `GET /dashboard/vas-trend`로 변화 확인.

## ⚠️ PoC 단순화 고지
- 인증·차단·암호화·환자/RBAC 미적용 → **실데이터·실환자 금지**, 로컬 개발 전용.
- 노출 미디어는 플레이스홀더(실제 자극 자료는 Clinical & Safety 검수 후 도입).
- 운영 승격 경로: [System Architect](../agents/system-architect.md) · [Backend/Data](../agents/backend-data.md).

→ 상위: [프로젝트 README](../README.md) · 계약: [API-CONTRACT](./API-CONTRACT.md)
