# 마케팅 오케스트라 — 백엔드 (P1 첫 코드)

소상공인 마케팅 서브에이전트 서비스의 **온보딩 기초자료 수집(베이스라인)** 백엔드.
설계 출처: [`../orchestrator.md`](../orchestrator.md) · [`../onboarding-intake.md`](../onboarding-intake.md)

> ⚠️ 도박 DTx 백엔드(`poc/backend`)와 **분리된 별도 프로젝트**다. 동일 가상환경(Django 5.2 + DRF)을 재사용한다.

## 실행
```bash
# poc/backend의 venv 재사용
source ../../poc/backend/.venv/bin/activate
cd marketing-orchestra/backend
python manage.py migrate
python manage.py runserver
```

## 데이터 모델 (onboarding/models.py)
| 모델 | intake 절 | KPI / 근거 |
| --- | --- | --- |
| `Merchant` | §2.0 | 공통 프로필·동의·목표 |
| `AcquisitionBaseline` | §2.1 | 신규유입·노출 / [M1][M11][M15] |
| `ConversionBaseline` | §2.2 | 전환율·객단가 / [M4][M5][M12][M13] |
| `RetentionBaseline` | §2.3 | 재방문·NPS / [M7][M8][M9][M10] |
| `CustomerTransaction` | §2.3·§4 | RFM/CLV 원천 [M8] ※가명·민감정보 |

모든 베이스라인엔 **데이터 신뢰등급(A/B/C/D)**(intake §1). `Merchant.overall_grade()`는 보수적으로 최악 등급을 종합한다.

## API (api/v1/)
| 메서드·경로 | 설명 |
| --- | --- |
| `POST /onboarding/merchants/` | 첫 만남 통합 등록(업체 + 3 베이스라인 중첩) |
| `GET /onboarding/merchants/{id}/card/` | 베이스라인 카드(KPI 스냅샷 + 데이터등급) |
| `POST /onboarding/transactions/` | 거래로그 적재(위탁처리 동의 전제, 미동의 403) |

## 원칙
- **측정 없이 성과 약속 금지** — 카드의 투영치는 항상 '추정'으로 명시(orchestrator §4.3).
- **개인정보 게이트** — 거래로그는 가명키만 저장, 동의 없으면 적재 거부(intake §4).
