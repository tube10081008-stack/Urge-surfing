# 🔌 PoC API 계약 (P0) — Flutter ↔ Django REST

> **P0 범위:** 노출(Exposure) 1종 + 충동 파도타기(Urge Surfing) + VAS 기록. **인증/차단 제외**(단일 데모 사용자).
> Base URL: `http://localhost:8000/api/v1` · 포맷: JSON · PoC 단순화: 정수 PK, SQLite, 인증 없음.

## 엔드포인트

### `GET /exposure-media`
노출 자극 라이브러리(시드 데이터).
```json
200 → [{"id":1,"title":"슬롯머신 릴 사운드","media_type":"audio","category":"슬롯","intensity":3,"asset_ref":"slot_reel"}]
```

### `POST /training-sessions`
```json
요청  {"session_type":"erp_exposure","media_id":1}      // session_type: erp_exposure | urge_surfing
201   {"id":10,"session_type":"erp_exposure","media_id":1,"started_at":"...","completed":false}
```

### `PATCH /training-sessions/{id}`
```json
요청  {"completed":true}
200   {"id":10,"completed":true,"ended_at":"...","duration_sec":214}
```

### `POST /training-sessions/{id}/vas`
```json
요청  {"phase":"pre","vas_value":8}     // phase: pre | post, vas_value: 0~10
201   {"id":3,"phase":"pre","vas_value":8,"recorded_at":"..."}
```

### `POST /urge-surfing`
```json
요청  {"session_id":10,"peak_urge":9,"outcome":"success","coping_skill":"breathing","duration_sec":180}
      // outcome: success | relapse | aborted
201   {"id":5,"session_id":10,"peak_urge":9,"outcome":"success","duration_sec":180}
```

### `GET /dashboard/vas-trend`
PoC 대시보드(단일 데모 사용자) — VAS 전후 변화.
```json
200 → [{"day":"2026-06-18","avg_pre":7.5,"avg_post":3.2,"avg_reduction":4.3}]
```

## 검증 규칙
- `vas_value` 0~10 정수. `outcome`/`phase`/`session_type`/`media_type`은 enum.
- 세션당 `phase`는 pre/post 각 1회.
- CORS: 로컬 개발용 전체 허용(`*`) — 운영 전환 시 제한.

> 이 계약은 [Backend/Data](../agents/backend-data.md) 스키마의 P0 부분집합. 운영 전환 시 UUID·JWT·TimescaleDB·환자/RBAC로 승격.
