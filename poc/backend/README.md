# 도박중독 DTx — P0 PoC 백엔드

Django REST Framework 기반 PoC 백엔드. 단일 데모 사용자 가정, 인증 없음, SQLite.

## 범위 (P0)
- 노출 자극 라이브러리(ERP)
- 훈련 세션(ERP 노출 / 충동 파도타기)
- VAS(주관적 갈망/고통 척도) 사전·사후 기록
- 충동 파도타기 결과
- 간단 대시보드 집계(일자별 VAS pre/post 평균 및 감소량)

> 차단/환자관리/RBAC/인증은 범위에서 제외.

## 실행법

```bash
# 1) 가상환경 생성 및 활성화
python -m venv .venv
source .venv/bin/activate           # Windows: .venv\Scripts\activate

# 2) 의존성 설치
pip install -r requirements.txt

# 3) DB 마이그레이션
python manage.py makemigrations
python manage.py migrate

# 4) 시드 데이터 적재 (노출 자극 4종)
python manage.py seed

# 5) 개발 서버 실행
python manage.py runserver
```

서버 기동 후 Base URL: `http://127.0.0.1:8000/api/v1`

## API 계약

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/exposure-media` | 노출 자극 목록 |
| POST | `/training-sessions` | 훈련 세션 생성 |
| PATCH | `/training-sessions/{id}` | 세션 완료 처리 |
| POST | `/training-sessions/{id}/vas` | VAS 기록(pre/post) |
| POST | `/urge-surfing` | 충동 파도타기 결과 |
| GET | `/dashboard/vas-trend` | 일자별 VAS 추세 |

## curl 예시

```bash
BASE=http://127.0.0.1:8000/api/v1

# 노출 자극 목록
curl -s $BASE/exposure-media | python -m json.tool

# ERP 노출 세션 생성 (media_id는 위 목록의 id 중 하나)
curl -s -X POST $BASE/training-sessions \
  -H 'Content-Type: application/json' \
  -d '{"session_type":"erp_exposure","media_id":1}' | python -m json.tool

# 사전 VAS 기록 (세션 id=1 가정)
curl -s -X POST $BASE/training-sessions/1/vas \
  -H 'Content-Type: application/json' \
  -d '{"phase":"pre","vas_value":8}' | python -m json.tool

# 사후 VAS 기록
curl -s -X POST $BASE/training-sessions/1/vas \
  -H 'Content-Type: application/json' \
  -d '{"phase":"post","vas_value":3}' | python -m json.tool

# 세션 완료 처리 (ended_at, duration_sec 자동 계산)
curl -s -X PATCH $BASE/training-sessions/1 \
  -H 'Content-Type: application/json' \
  -d '{"completed":true}' | python -m json.tool

# 충동 파도타기 세션 생성 + 결과 기록
curl -s -X POST $BASE/training-sessions \
  -H 'Content-Type: application/json' \
  -d '{"session_type":"urge_surfing"}' | python -m json.tool

curl -s -X POST $BASE/urge-surfing \
  -H 'Content-Type: application/json' \
  -d '{"session_id":2,"peak_urge":9,"outcome":"success","coping_skill":"호흡 명상","duration_sec":420}' | python -m json.tool

# 대시보드 VAS 추세
curl -s $BASE/dashboard/vas-trend | python -m json.tool
```

## 검증 규칙
- `vas_value`, `peak_urge`: 0~10
- `session_type`: `erp_exposure` | `urge_surfing`
- `media_type`: `audio` | `video` | `image`
- `phase`: `pre` | `post` (세션당 각 1회만, UniqueConstraint)
- `outcome`: `success` | `relapse` | `aborted`
- 충동 파도타기 결과는 세션당 1회(OneToOne)

## 구조
```
backend/
├── requirements.txt
├── manage.py
├── config/            # 프로젝트 설정 (settings/urls/wsgi/asgi)
└── core/              # 핵심 앱 (모델/시리얼라이저/뷰/URL/어드민)
    └── management/commands/seed.py
```
