# 🎨 Frontend/UX — Flutter UI·충동 파도타기 플로우
> 소속: DTx 도박중독 오케스트라 | 보고: Orchestrator

---

## 1. 정체성 & 임무

| 항목 | 내용 |
|---|---|
| **역할명** | Frontend/UX 서브에이전트 |
| **한 줄 정의** | 도박중독 DTx 앱의 모든 사용자 접점(화면·인터랙션·애니메이션)을 Flutter로 설계·구현하고, 치료적 효과가 발생하는 **'충동 파도타기' 세션의 사용자 경험을 책임지는 주체** |
| **임무** | (1) ERP(노출·반응방지)와 Urge Surfing 훈련이 **사용자를 압도하지 않으면서도 충분히 노출되게** 하는 UI를 만든다. (2) 비난 없는 톤·안정감·성취 시각화로 중도이탈을 막는다. (3) 임상 안전장치(중단·트리거경고·1336 위기버튼)를 항상 UI에 노출한다. |
| **핵심 철학** | "사용자는 환자가 아니라 **파도를 함께 견디는 동반자**다. 화면은 자극을 주되, 출구는 늘 보이게." |

> ⚠️ **치료적 긴장**: 노출 모듈은 의도적으로 갈망(craving)을 유발한다. 따라서 UX의 최우선 과제는 '몰입'이 아니라 **'안전하게 끝까지 머무르게 하는 것'**이다. 게임화는 동기부여 수준까지만, 도박적 보상 루프(랜덤 보상·연속 카운트 압박)는 **금지**한다.

---

## 2. 책임 범위

### 2.1 In-Scope (내가 책임짐)
- **화면 구성·정보구조(IA)**: 온보딩 → 주도박유형선택 → 홈 → 노출모듈 → 충동파도타기 → VAS입력 → 결과 → 차단경고 → 후원자설정 → 진도대시보드.
- **노출(Exposure) 모듈 UI/UX**: 자극 선택, 전체화면+사운드 재생, 안전장치(상시 중단버튼, 사전 트리거 경고, 사용시간 제한 타이머).
- **충동 파도타기 UI**: 카운트다운 타이머, 파도 CustomPainter 애니메이션(거친→잔잔), 호흡 가이드(Inhale/Exhale) 애니메이션, VAS 0~10 슬라이더(전·후), 주의분산 요소.
- **★핵심 산출물★**: '충동 파도타기' 세션 단계별 User Flow(이탈/실패 분기 포함).
- **접근성**: 동적 폰트(`MediaQuery.textScaler`), WCAG AA 색대비, 저자극(Low-Stimulation) 모드, 위기 1336 버튼 상시 노출.
- **상태관리 구조**: Riverpod provider 트리 설계.
- **오프라인 처리**: Hive 로컬 우선 기록, 온라인 복귀 시 동기화 큐.
- **디자인 원칙**: 비난 없는 카피, 안정 컬러 시스템, 성취 시각화.

### 2.2 Out-of-Scope (다른 에이전트가 책임짐)
| 영역 | 담당 |
|---|---|
| DB 스키마·REST 엔드포인트·JWT 발급 | Backend/Data |
| App Blocker OS권한·UsageStats·MethodChannel 네이티브 구현 | Native Integration |
| 임상 프로토콜·VAS 척도 타당성·1336 연계 의무·중단 임계치 | Clinical & Safety |
| 전체 아키텍처·모듈 경계·CI/CD | System Architect |

---

## 3. 협업 인터페이스

```
                    ┌────────────────────┐
                    │  System Architect  │  모듈 경계·라우팅 규약
                    └─────────┬──────────┘
                              │ (계약)
   Clinical&Safety           ▼            Backend/Data
   VAS척도/안전임계치 ──►  Frontend/UX  ◄── API 스펙(DTO/JWT)
   1336 연계규정             ▲
                              │ (MethodChannel 계약)
                    ┌─────────┴──────────┐
                    │ Native Integration │  AppBlocker/풀스크린/오디오
                    └────────────────────┘
```

| 협업 대상 | **입력 받음 (← 그들)** | **산출 제공 (→ 그들)** |
|---|---|---|
| **System Architect** | 모듈 경계, go_router 라우팅 트리 규약, 폴더 구조 컨벤션 | 화면별 라우트 정의, provider 의존성 그래프 |
| **Backend/Data** | REST DTO 스키마(세션/VAS/진도), JWT 갱신 정책, 오류 코드 | 클라이언트 전송 이벤트 페이로드, 오프라인 큐 동기화 요구사항 |
| **Native Integration** | MethodChannel 메서드 시그니처(`startBlocker`, `fullScreenMedia`, `audioFocus`), 콜백 이벤트 | 풀스크린 진입/이탈 라이프사이클 요구, 오디오 인터럽트 시 UI 처리 요구 |
| **Clinical & Safety** | VAS 0~10 척도 정의, 갈망 급상승 시 개입 임계치, 1336 노출 의무, 노출 최대 시간(임상 가이드) | 안전장치 UI 배치 검수 요청, 위기 분기 화면 시안 |

**계약 우선순위**: 임상 안전(Clinical) > 데이터 무결성(Backend) > UX 매끄러움. 충돌 시 상위가 이긴다.

---

## 4. 산출물

### 4.1 화면 목록 (Information Architecture)

| # | 화면 | 라우트 | 핵심 위젯/상태 | 안전장치 | 오프라인 |
|---|---|---|---|---|---|
| S1 | 온보딩 | `/onboarding` | `PageView`, `onboardingProvider` | 동의·면책, 1336 안내 | 로컬 |
| S2 | 주 도박유형 선택 | `/profile/gambling-type` | `ChoiceChip`, `gamblingTypeProvider` | — | 로컬 |
| S3 | 홈(대시보드 허브) | `/home` | `Scaffold`+카드 그리드 | **1336 상시 FAB** | 로컬 |
| S4 | 노출 모듈(자극선택) | `/exposure` | `exposureCatalogProvider` | 트리거 사전경고, 강도선택 | 캐시 자극 |
| S5 | 노출 재생(풀스크린) | `/exposure/play` | `VideoPlayer`/오디오, `exposurePlaybackProvider` | **상시 중단버튼, 사용시간 제한** | 캐시 |
| S6 | 충동 파도타기 | `/urge-surf` | `CustomPaint`(파도), `AnimationController`(호흡), `urgeSurfControllerProvider` | 타이머, 일시정지, 1336 | 완전 오프라인 |
| S7 | VAS 입력(전/후) | `/vas` (모달) | `Slider` 0~10, `vasProvider` | — | 로컬 큐 |
| S8 | 세션 결과 | `/session/result` | 전후 갈망 비교 차트 | 비난 없는 카피 | 로컬 |
| S9 | 차단 경고 | `/blocker/warning` | 네이티브 연동 화면, `blockerProvider` | 후원자 알림, 1336 | 로컬 |
| S10 | 후원자(서포터) 설정 | `/supporter` | 연락처/알림 설정 | 위기 시 통지 | 큐 동기화 |
| S11 | 진도 대시보드 | `/progress` | 스트릭·세션수·갈망감소 추이 | 성취 시각화 | 로컬 우선 |

---

### 4.2 ★ '충동 파도타기' 세션 User Flow (핵심 산출물) ★

#### 4.2.1 단계별 상세 플로우 (15단계)

| 단계 | 화면/상태 | 사용자 상호작용 | 기술 구현 (위젯·상태·애니메이션) | 데이터 이벤트 |
|---|---|---|---|---|
| **U0. 진입** | S3 홈 → "지금 충동이 와요" CTA | 큰 버튼 1탭 | `go_router.push('/urge-surf')` · `urgeSurfControllerProvider` 초기화(`UrgeState.idle`) | `session.start_intent` 로컬 기록 |
| **U1. 사전 안내** | 풀 가이드 카드 | "준비됐어요" 탭 / "그냥 넘기기" | `Stepper` 1of1, 저자극 페이드인 | — |
| **U2. 사전 VAS** | S7 슬라이더(전) | 갈망 0~10 드래그 후 확정 | `Slider`+햅틱, `vasProvider.preValue` | `vas.pre {value, ts}` 큐 적재 |
| **U3. 노출 분기** | 선택 다이얼로그 | "자극 노출 포함" / "노출 없이 진정만" | `AsyncNotifier` 분기 → 포함 시 U4, 미포함 시 U6 | `exposure.opted_in: bool` |
| **U4. 트리거 경고** | 전경 경고 시트 | "이해했고 진행" (홀드 1.5s) | `GestureDetector` long-press 게이트(오발 방지) | `exposure.consent` |
| **U5. 노출 재생** | S5 풀스크린 | 슬롯음/경마영상 시청, 언제든 중단 | `VideoPlayer`+오디오포커스(MethodChannel `audioFocus`), 상단 **상시 중단 X** + 잔여시간 링, `exposurePlaybackProvider` 60~90s 자동 cap | `exposure.play_start/end {type, durationMs}` |
| **U6. 충동 인식** | 전환 화면 | "지금 느낌에 머물러봐요" | `AnimatedSwitcher`로 파도 캔버스 페이드인, 상태 `UrgeState.surfing` | `urge.onset` |
| **U7. 타이머 시작** | S6 메인 | 자동(3~5분, 기본 180s) | `urgeSurfControllerProvider`의 `Ticker`+`Stream<Duration>`, 원형 진행 인디케이터 | `surf.timer_start {targetSec:180}` |
| **U8. 파도 애니메이션** | S6 배경 | 관찰(수동) | **`CustomPainter`+`AnimationController`**: 진폭(amplitude)을 경과시간에 따라 `1.0→0.15`로 보간 → "거친 파도가 잔잔해짐" 시각화. 60fps `repaint`는 `Listenable` 한정 | — (로컬 애니 상태) |
| **U9. 호흡 가이드** | S6 중앙 | Inhale/Exhale 따라하기 | 4-7-8 또는 4-4-6 사이클. `AnimationController`(reverse 반복)로 원 스케일 0.6↔1.0, 텍스트 "들이쉬기/멈춤/내쉬기" `TweenSequence` | `breath.cycle_count` 누적 |
| **U10. 실시간 코칭** | S6 하단 자막 | 읽기(수동), 선택적 "분산 활동" | 경과 비율 기반 메시지: 0~33% "파도는 정점을 지나요" / 33~66% "조금씩 약해지고 있어요" / 66~100% "잘 견디고 있어요". `coachingProvider`가 `progress`를 watch | `coach.tip_shown {tipId}` |
| **U11. 주의분산(옵션)** | 보조 시트 | "다른 곳에 집중" 탭 | 5-4-3-2-1 그라운딩 미니카드/색칠. 메인 타이머는 백그라운드 유지 | `distraction.used` |
| **U12. 타이머 완료** | S6 → 완료 펄스 | 자동 / "조금 더" 연장 | `Ticker` 완료 시 `UrgeState.completed`, 부드러운 성공 햅틱(과한 보상 금지) | `surf.timer_complete {actualSec}` |
| **U13. 사후 VAS** | S7 슬라이더(후) | 갈망 0~10 재입력 | `vasProvider.postValue`, 슬라이더 옆 사전값 ghost 표시 | `vas.post {value, ts}` |
| **U14. 피드백/결과** | S8 결과 | 전후 비교 확인, "완료" | 갈망 Δvalue를 막대/곡선으로. **감소든 아니든 비난 없는 카피**("머문 것 자체가 훈련이에요") | `session.summary {pre,post,delta,durationSec}` |
| **U15. 데이터 전송** | 백그라운드 | 없음 | 온라인: `sessionRepository.sync()` → Django REST(JWT). 오프라인: Hive 큐 보존, 연결복귀 시 자동 flush | `session.synced` / `session.queued` |

#### 4.2.2 이탈·실패·위기 분기 (Edge & Safety Branches)

| 분기 코드 | 트리거 | UX 처리 | 상태/데이터 |
|---|---|---|---|
| **B1. 조기중단(노출 중)** | U5에서 중단 X 탭 | 파도/호흡 화면(U6)으로 **부드럽게 전환** — "잘 멈췄어요, 같이 진정해봐요" (실패 아님) | `UrgeState.surfing`, `exposure.aborted` |
| **B2. 세션 포기** | U7~U11 중 뒤로가기/종료 시도 | 종료 확인 시트: "지금 멈추면 충동이 더 셀 수 있어요. 1분만 더?" / "그래도 종료" | `session.abandoned {atSec, lastState}` (비난 X) |
| **B3. 갈망 급상승** | U13 사후 VAS ≥ 임상 임계치(예: ≥8) **또는** post>pre | 자동 개입: 호흡 1사이클 추가 제안 + **1336/후원자 연결 카드 강조** | `safety.escalation {reason}` → 후원자 통지 큐 |
| **B4. 위기 신호** | 어느 화면이든 **상시 1336 버튼** 탭 | 즉시 통화 인텐트(`url_launcher tel:1336`) 확인 다이얼로그, 세션은 일시정지 보존 | `safety.crisis_tap` |
| **B5. 앱 백그라운드/전화** | OS 인터럽트(`AppLifecycleState.paused`) | 타이머 일시정지·오디오 mute, 복귀 시 "다시 이어서?" | `session.interrupted` |
| **B6. 오프라인 전송 실패** | U15 네트워크 없음 | 무중단(사용자 인지 없음), 로컬 큐 적재 + 다음 실행/연결복귀 시 flush | `session.queued`, 재시도 backoff |
| **B7. 노출 미디어 로드 실패** | U5 자산 없음 | 캐시 폴백 → 없으면 **자극 없이 U6 진정 모드로 우아하게 강등** | `exposure.fallback` |

#### 4.2.3 상태 머신 (순서도)

```
        ┌──────────────────────────── B4(1336) ──── 어디서든 ────┐
        │                                                       ▼
 idle ──U0──► preVas ──U3──┬─(opt-in)─► triggerWarn ──► exposing ──┐
                            │                              │(B1)   │
                            └────(skip)────────────────────┴───────▼
                                                                surfing
                                                          (파도+호흡+코칭)
                                                                 │
                                       ┌──(B2 포기)──┐            │
                                       ▼             │           ▼
                                  abandoned          └────── completed
                                                                 │
                                                              postVas
                                                                 │
                                              ┌──(B3 급상승)──► escalation ──► 후원자/1336
                                              ▼
                                            result ──► sync ──┬─ online: POST(JWT)
                                                              └─ offline: queue(Hive)
```

---

### 4.3 컴포넌트 / 상태 설계 (Riverpod)

#### 4.3.1 Provider 트리

```dart
// === 세션 오케스트레이션 ===
final urgeSurfControllerProvider =
    NotifierProvider<UrgeSurfController, UrgeSurfState>(UrgeSurfController.new);

// === VAS (전/후 갈망 0~10) ===
final vasProvider = NotifierProvider<VasNotifier, VasState>(VasNotifier.new);

// === 노출 ===
final exposureCatalogProvider =            // 주 도박유형 기반 맞춤 자극 목록
    FutureProvider.family<List<Stimulus>, GamblingType>((ref, type) =>
        ref.read(exposureRepositoryProvider).catalogFor(type));
final exposurePlaybackProvider =
    NotifierProvider<ExposurePlayback, PlaybackState>(ExposurePlayback.new);

// === 실시간 코칭(파생) ===
final coachingProvider = Provider<CoachingTip>((ref) {
  final s = ref.watch(urgeSurfControllerProvider);
  return CoachingTip.fromProgress(s.progress); // 0..1
});

// === 안전 ===
final safetyProvider =                     // 1336·후원자·에스컬레이션
    NotifierProvider<SafetyNotifier, SafetyState>(SafetyNotifier.new);

// === 오프라인 동기화 ===
final sessionRepositoryProvider = Provider((ref) =>
    SessionRepository(hive: ref.read(hiveBoxProvider), api: ref.read(apiProvider)));
final syncQueueProvider =
    NotifierProvider<SyncQueue, List<PendingEvent>>(SyncQueue.new);
```

#### 4.3.2 핵심 상태 모델

```dart
enum UrgeState { idle, preVas, exposing, surfing, completed, postVas, result }

class UrgeSurfState {
  final UrgeState phase;
  final Duration elapsed;
  final Duration target;        // 기본 180s (3~5분 구간)
  final bool exposureOptedIn;
  final double waveAmplitude;   // 1.0(거침) → 0.15(잔잔), progress로 보간
  double get progress =>
      target.inMilliseconds == 0 ? 0 : elapsed.inMilliseconds / target.inMilliseconds;
  const UrgeSurfState({ /* ... */ });
}
```

#### 4.3.3 파도 애니메이션 (CustomPainter 스니펫)

```dart
class WavePainter extends CustomPainter {
  WavePainter({required this.t, required this.amplitude}) ;
  final double t;          // AnimationController 0..1 (반복)
  final double amplitude;  // urgeSurfState.waveAmplitude (시간따라 감쇠)

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height * 0.5);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 +
          math.sin((x / size.width * 2 * math.pi) + t * 2 * math.pi)
              * (size.height * 0.25 * amplitude); // amplitude↓ → 잔잔
      path.lineTo(x, y);
    }
    path..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4A7C9E));
  }
  @override
  bool shouldRepaint(WavePainter o) => o.t != t || o.amplitude != amplitude;
}
```

> 성능: `CustomPaint(isComplex:true, willChange:true)` + `RepaintBoundary`로 격리. 저자극 모드에서는 `amplitude` 변화량·프레임레이트를 낮춰 motion 민감 사용자 보호.

---

### 4.4 접근성 (Accessibility)

| 항목 | 구현 |
|---|---|
| **동적 폰트** | 모든 텍스트 `MediaQuery.textScaler` 반영, 레이아웃 `FittedBox`/스크롤 허용 (200%까지 무파손) |
| **색 대비** | 본문/버튼 WCAG **AA(4.5:1)** 이상, 안정 팔레트(블루-그린) 기준 토큰화 |
| **저자극 모드** | 토글 시 파도 진폭·애니속도 ↓, 사운드 기본 OFF, 고대비 단색 테마 |
| **위기 1336 버튼** | 모든 화면 `Scaffold`에 **상시 FAB/AppBar 액션** 고정, `Semantics(label:'위기상담 1336 전화')` |
| **스크린리더** | 슬라이더 `Semantics(value:'갈망 7 / 10')`, 타이머 `liveRegion` |
| **터치 타깃** | 최소 48x48dp, VAS 슬라이더 thumb 확대 + 햅틱 |

### 4.5 디자인 원칙 (중독자 심리)

1. **비난 없는 톤(Non-judgmental)**: 실패/재발 카피 금지. "머문 것 자체가 훈련" / "잘 멈췄어요". 빨강 경고색은 안전(1336)에만.
2. **안정감(Calm)**: 저채도 블루-그린, 느린 이징(`Curves.easeInOutSine`), 급격한 모션·강한 효과음 배제.
3. **성취 시각화(Mastery, not gambling)**: 스트릭·갈망감소 추이는 **연속 압박/랜덤 보상 없이** 누적·완만 곡선으로. 도박 보상 루프(코인·잭팟 연출) **절대 금지**.
4. **출구 우선(Exit-always-visible)**: 노출·서핑 어떤 순간에도 중단·종료·1336가 화면에 보인다.

---

## 5. 핸드오프 체크리스트

### 5.1 산출 완료 기준 (Definition of Done)
- [ ] 화면 11종 라우트(go_router) 정의 → System Architect 검토 완료
- [ ] 충동 파도타기 User Flow 15단계 + 7개 분기 → Clinical & Safety 안전 임계치(B3 ≥8, 노출 cap) 합의
- [ ] Riverpod provider 트리·상태모델 → System Architect 의존성 검토
- [ ] 데이터 이벤트 페이로드(`vas.pre/post`, `session.summary` 등) → Backend/Data DTO 매핑 확정
- [ ] MethodChannel 계약(`audioFocus`, `fullScreenMedia`, `startBlocker`) → Native Integration 시그니처 합의
- [ ] 접근성: 폰트 200%·AA 대비·저자극·1336 상시 → Clinical 검수 통과
- [ ] 오프라인: Hive 큐 적재/flush 시나리오(B6) 검증

### 5.2 차단 의존성 (Blocked-by)
| 항목 | 대기 대상 | 위험 |
|---|---|---|
| VAS 척도·B3 임계치·1336 의무 | Clinical & Safety | 미정 시 안전 분기 구현 불가 |
| 세션/VAS/진도 DTO·JWT 정책 | Backend/Data | U15 전송·B6 큐 스키마 확정 불가 |
| 풀스크린·오디오포커스·차단 채널 | Native Integration | U5/S9 동작 불가 |
| 라우팅 트리·폴더 컨벤션 | System Architect | provider 배선 충돌 위험 |

### 5.3 다음 에이전트로의 인계물
- → **Backend**: 이벤트 카탈로그(JSON) + 오프라인 멱등키 요구.
- → **Native**: 풀스크린 라이프사이클·오디오 인터럽트 UI 콜백 요구.
- → **Clinical**: 충동 파도타기 화면 시안 + 안전 분기(B1~B4) 검수 요청.
- → **Architect**: provider 의존성 그래프 + 라우트 맵.

---
*문서 버전 v1.0 · 작성: Frontend/UX 서브에이전트 · 2026-06-18*
