# ✅ 검증 리포트 — 에이전트 조직 정합성 & RAG 설계 타당성

> Orchestrator가 수행한 6개 에이전트 문서 + RAG 레이어의 교차검증 결과.
> 검증 기준: ① 에이전트 간 **계약 일관성** ② **안전·규제 커버리지** ③ RAG 설계의 **논문 근거 정합성**.

---

## 1. 계약 일관성 (에이전트 간 인터페이스)

| 계약 | 출처 | 소비처 | 일치 여부 |
| --- | --- | --- | --- |
| MethodChannel(`block/unblock/queryUsage/onBlockEvent`) | System Architect | Frontend/UX, Native Integration | ✅ 3개 문서 일치 |
| 오프라인 동기화 `/sync` + `client_event_id`(멱등) | Backend/Data | Frontend/UX, Native Integration | ✅ 일치 (멱등키 규약 동일) |
| VAS 0~10 척도 | Backend(`vas_records`) | Frontend(슬라이더), Clinical, Architect | ✅ 일치 |
| 위기 에스컬레이션 **1336** | Clinical & Safety | 전 5개 문서 | ✅ 전부 관통 |
| `blocking_events` 페이로드 | Native Integration | Backend(스키마), Architect(흐름B) | ✅ 일치 |
| 감사로그 append-only | Architect, Backend | Clinical(규제) | ✅ WORM 일치 |

> **결론:** 핵심 데이터·제어 계약은 문서 간 모순 없음. 병렬 작성에도 SSOT(orchestrator §3) 전제 덕분에 정합.

---

## 2. 안전·규제 커버리지

| 요건 | 충족 문서 | 상태 |
| --- | --- | --- |
| 노출 자극의 갈망 촉발 위험(트리거) | Architect K5, Clinical 4.2 | ✅ 단계적 노출+고VAS 에스컬레이션 |
| 위기(자해/자살) 대응 | Clinical 4.2 (1336·109) | ✅ |
| 민감 건강정보 보호(PIPA) | Architect 4.5, Backend 4.5 | ✅ AES-256·국내리전·동의관리 |
| 식약처 SaMD(IEC 62304 등) | Clinical 4.3, Architect K8 | ✅ 추적성·감사 |
| 차단의 윤리(자율성 vs 강제) | Clinical 4.4 (Ulysses 계약) | ✅ 사전동의 기반 |
| **임상 출력의 근거·인용** | knowledge-rag §3 (MedGraphRAG) | ✅ **신규 보강** |

---

## 3. RAG 설계의 논문 근거 정합성

| RAG 설계 요소 | 근거 논문 | 검증 |
| --- | --- | --- |
| 비파라미터 외부지식 + 출처 제시 | [R1] Lewis 2020 | ✅ 원전 개념 정확 반영 |
| 3계층 그래프·U-retrieve·내재 인용 | [R2] MedGraphRAG | ✅ §2.1·U-retrieve 정확 인용 |
| 중앙집중 멀티에이전트 오케스트레이션 | [R3] Survey §5.2 | ✅ 우리 구조와 동형 |
| 검색⇄추론 시너지(복잡 질의) | [R3] Survey §5 | ✅ Deep Research식 반영 |
| pgvector로 기존 스택 재사용 | [R1] 원리 + Architect 스택 | ✅ 신규 DB 없이 정합 |

---

## 4. 발견된 갭 & 후속 조치(TODO)

| # | 갭 | 담당 | 우선순위 |
| --- | --- | --- | --- |
| G1 | 런타임 AI 코치(환자/임상가)의 **세부 프롬프트·거부 정책** 미정 | Knowledge & RAG + Clinical | 高 |
| G2 | RAG **검색·인용 이벤트의 audit_log 스키마** 미반영(현 17테이블에 `rag_query_log` 추가 검토) | Backend/Data | 中 |
| G3 | 한국어 임베딩 모델 **임상용어 커버리지** 평가 미수행 | Knowledge & RAG | 中 |
| G4 | Clinical 코퍼스(문헌·UMLS)의 **저작권·라이선스** 확인 | Clinical & Safety | 高 |
| G5 | iOS 차단 한계(불투명 토큰) ↔ RAG 코치의 "차단 우회 시 대처" 안내 연계 미설계 | Native + Knowledge | 中 |
| G6 | [R4] 4번째 자료 미수령 → RAG 근거 1건 보강 대기 | Orchestrator | — |

---

## 5. 종합 판정

> **PASS (조건부).** 6개 에이전트 + RAG 레이어는 계약·안전·논문근거 측면에서 정합적이며 구현 착수 가능. 단 **G1·G4(高)**는 PoC 전 해소 필요.

→ 관련: [Orchestrator](./orchestrator.md) · [knowledge-rag](./agents/knowledge-rag.md) · [references](./references.md)
