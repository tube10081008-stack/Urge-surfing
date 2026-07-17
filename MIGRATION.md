# 프로젝트 분리(모노레포 → 독립 저장소) 기록

이 저장소(`tube10081008-stack/Urge-surfing`)에는 서로 무관한 5개 프로젝트가
브랜치·폴더로 공존해 왔습니다. **진짜 병목은 "폴더 분리"가 아니라 "저장소 분리"**였고,
지난 세션에서는 GitHub 권한이 이 저장소 하나로만 제한돼 다른 저장소로 push할 수 없었습니다.

이번 세션에서는 대상 저장소 3곳(`geo-marketing`, `jogeum-ledger`, `slowstep-pos-`)에
접근 권한이 열려서, 각 프로젝트 폴더를 **히스토리 보존(`git subtree split`)** 상태로
독립 저장소의 루트로 분리해 push했습니다.

## 분리 결과 — 어느 프로젝트가 어디로 나가는가

| 프로젝트 | 구 위치 (Urge-surfing) | 독립 저장소 | 브랜치 | 호스팅 | 라이브 URL(재연결 후) | 저장/DB |
|---|---|---|---|---|---|---|
| GEO 마케팅(복어·코라) | `marketing-orchestra/` @ `wonderful-lovelace-54xws3` | `tube10081008-stack/geo-marketing` | `claude/multi-project-bottleneck-analysis-ppa8qq` | Vercel(web) + Render(backend) | `*.vercel.app` + `geo-marketing-api.onrender.com` | Render PostgreSQL |
| 조구미 가계부 | `ledger/` @ `app-deployment-process-51gcg1` | `tube10081008-stack/jogeum-ledger` | `claude/multi-project-bottleneck-analysis-ppa8qq` | GitHub Pages | `tube10081008-stack.github.io/jogeum-ledger/` | localStorage + Gist |
| slowstep-pos | `slowstep-pos/` @ `new-project-setup-hz2qo8` | `tube10081008-stack/slowstep-pos-` | `claude/multi-project-bottleneck-analysis-ppa8qq` | Vercel + Render(선택) | Vercel 프로젝트 도메인 | SQLite(데모) |
| notebookllm | (해당 없음 — 별개 저장소) | `tube10081008-stack/notebookllm` | `main` 등 | Vercel | 자체 도메인 | — |
| livetranslate / 도박중독 DTx PoC | `poc/`, `nice-heisenberg-lytdqa` 등 | (분리 안 함 — 실험 종료/레거시) | — | — | — | (구)PostgreSQL |

각 독립 저장소는 자기 프로젝트만 루트에 두므로, 브랜치가 서로의 폴더 사본을 안 들고
Vercel "전 브랜치 빌드" 교차나 Pages URL 쟁탈이 원천적으로 사라집니다.

## 자동으로 처리한 것 (①·②)

- **① 히스토리 분리**: `git subtree split -P <폴더>` 로 각 폴더를 루트로 끌어올린
  독립 히스토리 생성 (geo=21커밋 / ledger=11커밋 / slowstep=15커밋).
- **② 새 저장소로 push**: 위 세 대상 저장소의
  `claude/multi-project-bottleneck-analysis-ppa8qq` 브랜치로 push 완료.
- **경로 조정(상위 경로 개별 설정)**:
  - `geo-marketing/render.yaml` 신규 추가 — `rootDir: backend`, 분리 브랜치 타깃.
  - `slowstep-pos-/render.yaml` — `rootDir: slowstep-pos/backend → backend`, 브랜치 갱신.
  - `jogeum-ledger/.github/workflows/deploy-pages.yml` 이식 — `path: ledger → .`, 분리 브랜치 트리거.

## 사장님이 하실 일 (③ 호스팅 재연결 — 대시보드 권한 필요)

제 권한 밖(대시보드 클릭)이라 아래는 직접 해주셔야 합니다:

1. **geo-marketing**: Vercel 새 프로젝트를 `geo-marketing` 저장소·Root `web/` 로 연결,
   Render는 `render.yaml` Blueprint로 연결. 새 Vercel 도메인이 나오면
   `render.yaml`의 `CORS_ALLOWED_ORIGINS` 를 그 도메인으로 갱신.
2. **jogeum-ledger**: 저장소 Settings → Pages → Source = **GitHub Actions** 로 한 번 설정.
   이후 자체 URL `.../jogeum-ledger/` 로 배포됨.
3. **slowstep-pos-**: Vercel 프로젝트를 이 저장소로 연결(Root = 저장소 루트, `vercel.json` 사용).
   기존 유령 프로젝트 `urge-surfing-jaip`(구 slowstep 대상, 엉뚱한 브랜치 감시로 실패)는
   삭제하거나 이 저장소로 재연결.

## 이 모노레포(Urge-surfing)는?

분리 후에도 기존 브랜치/폴더/배포는 **건드리지 않았습니다**(GEO가 아직 라이브라 안전 우선).
정리(폴더 제거)는 재연결·검증이 끝난 뒤 별도로 진행하시면 됩니다.
