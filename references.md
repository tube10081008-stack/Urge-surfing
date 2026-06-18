# 📚 참고문헌 (RAG 근거 자료)

> 본 프로젝트의 [지식 증강(RAG) 레이어](./agents/knowledge-rag.md)가 인용·적용하는 1차 자료.
> 인용 표기: `[R1]`, `[R2]`, `[R3]`.

---

## <a id="r1"></a>[R1] RAG — 검색 증강 생성의 원전
**Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks**
Lewis et al., 2020 (Facebook AI Research / UCL / NYU). arXiv:2005.11401
- **핵심:** 파라미터(머릿속) 기억 + **비파라미터(외부 문서) 기억**을 결합. 검색기(DPR)+생성기(BART).
- **우리에게:** 지식 갱신을 재학습 없이 문서 교체로 처리, **결정의 출처(provenance)** 제시 가능 → SaMD 규제·신뢰성의 토대.
- **적용:** 전 에이전트 공통 RAG 원리(검색→생성), pgvector 기반 Dense 검색.

## <a id="r2"></a>[R2] MedGraphRAG — 안전한 의료 RAG
**Medical Graph RAG: Towards Safe Medical LLM via Graph Retrieval-Augmented Generation**
Wu, Zhu, Qi, 2024 (University of Oxford). arXiv:2408.04187
- **핵심:** **3계층 계층형 의료 그래프**(사용자 자료 → 권위 의학문헌 → UMLS 사전), 시맨틱 청킹(명제변환+슬라이딩윈도우), **U-retrieve**(탑다운 검색+바텀업 생성), **내재적 출처 인용**으로 근거기반·감사가능. RAG만으로 파인튜닝된 의료 LLM을 능가.
- **우리에게:** 갈망을 유발하는 앱의 **임상·안전 출력은 반드시 근거 추적 가능**해야 함 → Clinical & Safety + 런타임 AI 코치의 표준.
- **적용:** [knowledge-rag §3](./agents/knowledge-rag.md), [clinical-safety](./agents/clinical-safety.md).

## <a id="r3"></a>[R3] Agentic RAG + Deep Reasoning (서베이)
**Towards Agentic RAG with Deep Reasoning: A Survey of RAG-Reasoning Systems in LLMs**
Li, Zhang, et al., 2025 (Tsinghua / UIC / Tokyo 외). arXiv:2507.09477
- **핵심:** RAG 3단계(검색·통합·생성), 3대 패러다임(Reasoning→RAG / RAG→Reasoning / **Synergized RAG⇔Reasoning**), 추론 워크플로(Chain/Tree/Graph), **에이전트 오케스트레이션**(단일 / 분산 멀티 / **중앙집중 멀티=매니저+작업에이전트**).
- **우리에게:** 우리의 **오케스트레이터+서브에이전트** 구조 = 중앙집중 멀티에이전트. 복잡 임상 질의는 검색⇄추론 반복(Deep Research식).
- **적용:** [knowledge-rag §4](./agents/knowledge-rag.md), [orchestrator](./orchestrator.md).

---

## <a id="r4"></a>[R4] (대기) 네번째 자료
> 사용자 제공 예정 — Google Drive 링크는 현 환경 네트워크 정책(egress allowlist)으로 접근 불가(403).
> **채팅에 직접 첨부**(앞 3개와 동일 방식)하면 즉시 추출·반영. 자리표시자로 `[R4]`를 예약해 둠.
