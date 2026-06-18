# 🎰🛟 도박중독 디지털치료제(DTx) — 멀티에이전트 설계 조직

> VR 없이 **스마트폰만으로** 도박장애의 ERP(노출·반응방지)와 **충동 파도타기(Urge Surfing)**를 훈련하는 모바일 디지털치료기기.
> 이 폴더는 앱을 만드는 **AI 에이전트 유기체**의 지침서 모음이다 — 총괄 1 + 전문가 5.

---

## 🧬 에이전트 조직도

```
                    🎯 Orchestrator
         전체 비전 · 기술 결정 · 충돌 조정 · 안전 게이트
                          │
   ┌───────────┬──────────┼──────────┬───────────────┐
 🏛️ System    🎨 Frontend  🗄️ Backend  📱 Native      🩺 Clinical
   Architect    /UX         /Data       Integration    & Safety
```

| 에이전트 | 지침서 | 담당 산출물 |
| --- | --- | --- |
| 🎯 **Orchestrator** | [`orchestrator.md`](./orchestrator.md) | 확정 기술결정·조율규칙·로드맵·추가기능 |
| 🏛️ **System Architect** | [`agents/system-architect.md`](./agents/system-architect.md) | 시스템 아키텍처·기술스택·인프라·리스크 |
| 🎨 **Frontend/UX** | [`agents/frontend-ux.md`](./agents/frontend-ux.md) | Flutter 화면·**충동 파도타기 유저플로우(15단계)** |
| 🗄️ **Backend/Data** | [`agents/backend-data.md`](./agents/backend-data.md) | **DB 스키마·DTx 대시보드 API**·성과지표 |
| 📱 **Native Integration** | [`agents/native-integration.md`](./agents/native-integration.md) | **App Blocker 권한·백그라운드 차단**·헬퍼 알림 |
| 🩺 **Clinical & Safety** | [`agents/clinical-safety.md`](./agents/clinical-safety.md) | 의학근거·식약처 규제·**위기 대응(1336)**·윤리 |
| 🧠 **Knowledge & RAG** | [`agents/knowledge-rag.md`](./agents/knowledge-rag.md) | 전 에이전트 **지식 증강(RAG)**·MedGraphRAG·근거 인용 |

> 📎 **부속 문서:** [참고문헌(RAG 근거 3편)](./references.md) · [검증 리포트](./verification-report.md)

---

## 🩺 무엇을 만드나 (핵심 4기능)

| # | 기능 | 한 줄 |
| --- | --- | --- |
| 1 | **노출(Exposure)** | 맞춤 시청각 자극(슬롯음·경마영상)으로 갈망을 *안전하게* 유발 |
| 2 | **반응 방지 / 충동 파도타기** | 갈망이 파도처럼 지나갈 때까지 견디기 — 타이머·파도/호흡 애니메이션·VAS 0~10 |
| 3 | **이행 장치(Commitment Device)** | OS레벨 도박앱 강제차단 + 후원자·1336 자동 알림 |
| 4 | **DTx 대시보드** | 식약처 심사용 데이터 로깅 + 의사·상담사 웹 대시보드 |

---

## ⚙️ 확정 기술 스택 (요약)

| 레이어 | 선택 |
| --- | --- |
| 모바일 | **Flutter** (Riverpod, 커스텀 애니메이션) |
| 백엔드 | **Django REST Framework** |
| DB | **PostgreSQL + TimescaleDB** |
| 임상 대시보드 | React |
| 차단(iOS) | FamilyControls / Screen Time API |
| 차단(Android) | AccessibilityService + Foreground Service |
| 알림 | FCM/APNs + SMS/전화(후원자·1336) |

> 상세 근거·트레이드오프는 [Orchestrator](./orchestrator.md) §3 및 [System Architect](./agents/system-architect.md).

---

## 🧭 이 조직을 읽는 순서
1. [`orchestrator.md`](./orchestrator.md) — 전체 그림·결정·규칙 (여기부터)
2. [`agents/system-architect.md`](./agents/system-architect.md) — 시스템 뼈대
3. [`agents/frontend-ux.md`](./agents/frontend-ux.md) / [`backend-data.md`](./agents/backend-data.md) / [`native-integration.md`](./agents/native-integration.md) — 각 레이어
4. [`agents/clinical-safety.md`](./agents/clinical-safety.md) — 안전·규제 (모든 결정의 게이트)

---

## ⛑️ 안전 고지
본 시스템은 도박 갈망을 *의도적으로 유발*하므로 안전장치가 기능보다 우선한다. 전문 치료를 **보조**하며 대체하지 않는다.
**위기 자원: 도박문제 헬프라인 1336 · 자살예방상담 109**
