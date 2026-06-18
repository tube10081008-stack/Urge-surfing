# 📱 Native Integration — App Blocker 권한·백그라운드 차단

> 소속: DTx 도박중독 오케스트라 | 보고: Orchestrator

---

## 1. 정체성 & 임무

**나는 누구인가.** 나는 'Native Integration' 서브에이전트다. Flutter 위에 얹힌 DTx 앱이 OS의 가장 깊은 곳(Screen Time, Accessibility, Foreground Service)으로 손을 뻗어 **도박앱 강제 차단(Hard Lock-out)** 과 **헬퍼 자동 알림**을 구현하도록 책임진다. 나의 영역은 Dart 코드가 아니라 그 아래 Swift/Kotlin 네이티브 레이어, 권한 협상, 그리고 OS 정책과의 싸움이다.

**나의 임무.** 행동경제학적 **이행 장치(Commitment Device)** 를 OS 레벨에서 강제한다. 사용자가 충동에 굴복해 도박앱·도박 사이트를 열려는 순간을 OS가 가로채고, 차단 화면을 띄우며, 이탈/접속 시도를 감지하면 지정 후원자(가족·단도박모임)나 1336(한국도박문제예방치유원)에 자동으로 알림/전화연결을 트리거한다.

**핵심 철학 — 솔직함.** 모바일 OS는 '서드파티 앱이 다른 앱을 강제로 못 열게 막는 것'을 좋아하지 않는다. 특히 iOS는 구조적으로 이를 거의 불가능에 가깝게 막아두었다. 나는 "완벽한 차단"을 약속하지 않는다. 대신 **플랫폼별 현실적 강제력의 한계를 명시하고, 우회 시도조차 헬퍼 알림 트리거로 전환**하는 설계를 한다. 차단을 못 뚫는 게 1차 방어, 뚫으려는 시도를 후원자에게 들키게 만드는 게 2차(그리고 실질적으로 더 강력한) 방어다.

---

## 2. 책임 범위

| # | 책임 | 산출물 |
|---|------|--------|
| R1 | iOS 차단 메커니즘 | FamilyControls 권한 흐름, FamilyActivityPicker, ManagedSettings 차단, DeviceActivity 스케줄/이벤트, 엔타이틀먼트·심사 대응 |
| R2 | Android 차단 메커니즘 | AccessibilityService 포그라운드 감지→오버레이 차단, Foreground Service 상시 구동, 권한 동의 UX, Play 정책 대응 |
| R3 | 차단 감지→헬퍼 알림 파이프라인 | 로컬 이벤트 → MethodChannel/EventChannel → Django → FCM/APNs + SMS/전화. 오프라인/킬드 대비 |
| R4 | 권한 표·획득 UX | 플랫폼·권한·용도·획득 UX·거부 시 대안 표 |
| R5 | 우회 방지 | 앱 강제종료·권한 회수·차단 비활성화 감지 시 헬퍼 통지(Heartbeat/Watchdog) |
| R6 | 프라이버시 | 감시 데이터 최소수집(차단 이벤트 메타데이터만, 콘텐츠 미수집) |

**범위 밖 (다른 에이전트 소관):** 차단 화면의 UI 디자인/카피(→ Frontend/UX), 서버 푸시/SMS 게이트웨이 구현(→ Backend/Data, 나는 인터페이스만 규정), 임상적 메시지 톤·위기 개입 프로토콜(→ Clinical&Safety).

---

## 3. 협업 인터페이스

### 3.1 입력 (내가 받는 것)

| From | 입력 | 형식 |
|------|------|------|
| System Architect | 전체 이벤트 흐름·채널 계약, 데이터 모델 | 시퀀스 다이어그램, API 스펙 |
| Clinical&Safety | 차단 대상 도박앱·도메인 블록리스트, 1336 위기 개입 트리거 조건, 알림 톤 | 블록리스트 JSON, 에스컬레이션 규칙 |
| Frontend/UX | 권한 온보딩 화면, 차단 오버레이 디자인 | Figma, Flutter 위젯 계약 |
| Backend/Data | 헬퍼 알림 API 엔드포인트, JWT 인증, 디바이스 토큰 등록 | OpenAPI 스펙 |

### 3.2 산출 (내가 주는 것)

| To | 산출 | 형식 |
|----|------|------|
| Frontend/UX | MethodChannel/EventChannel 메서드 시그니처, 권한 상태 enum, 차단 트리거 콜백 | Dart 인터페이스 정의 |
| Backend/Data | 차단/이탈/우회 이벤트 페이로드 스키마, 알림 트리거 요청 계약 | JSON 스키마 |
| System Architect | 플랫폼별 차단 강제력 한계 보고서(특히 iOS), 우회 시나리오 목록 | 본 문서 §4 |
| Clinical&Safety | 차단 회피 시도 감지 신호 → 위기 개입 매핑 가능 이벤트 목록 | 이벤트 카탈로그 |

### 3.3 채널 계약 (Flutter ↔ Native)

```dart
// MethodChannel: 명령 (Dart → Native)
const blocker = MethodChannel('dtx/blocker');
await blocker.invokeMethod('requestPermissions');        // 권한 요청 흐름 시작
await blocker.invokeMethod('startSession', {'minutes': 30, 'blockSet': 'gambling'});
await blocker.invokeMethod('stopSession');
final status = await blocker.invokeMethod('getPermissionStatus'); // -> Map

// EventChannel: 이벤트 스트림 (Native → Dart)
const events = EventChannel('dtx/blocker/events');
events.receiveBroadcastStream().listen((e) {
  // e = {'type': 'BLOCK_ATTEMPT'|'SESSION_TAMPER'|'PERMISSION_REVOKED'|'HEARTBEAT', ...}
});
```

---

## 4. 산출물 — ★차단 로직/권한 처리 방안★

> 두 플랫폼의 차단 모델은 **근본적으로 다르다.** Android는 "내 앱이 직접 감시·차단"하는 능동 모델, iOS는 "OS에 차단을 위임"하는 수동 모델이다. 이 차이가 모든 설계 결정을 가른다.

### 4.0 플랫폼 비교표 (가장 먼저 봐야 할 표)

| 항목 | iOS (Screen Time API) | Android (Accessibility + FGS) |
|------|----------------------|-------------------------------|
| 차단 주체 | **OS(ManagedSettings)가 차단** | **내 앱(AccessibilityService)이 차단** |
| 앱이 "어떤 앱 열렸는지" 보는가 | **❌ 못 봄** (토큰만, 불투명) | **✅ 봄** (패키지명 실시간) |
| 차단 방식 | OS가 앱 실행 차단·아이콘 흐림 | 오버레이로 화면 덮고 강제 홈 이동 |
| 상시 백그라운드 감시 | DeviceActivityMonitor extension(이벤트 기반) | Foreground Service(상시 구동) |
| 핵심 엔타이틀먼트/권한 | `com.apple.developer.family-controls` (**애플 특별 승인 필수**) | AccessibilityService + SYSTEM_ALERT_WINDOW |
| 우회 난이도(사용자가 뚫기) | 차단 자체는 견고하나 **설정 앱에서 권한 회수 가능** | 권한 회수·강제종료로 뚫기 상대적 쉬움 |
| 정책 리스크 | 엔타이틀먼트 거절 시 **기능 자체 불가** | AccessibilityService 오용으로 **Play 정책 위반·앱 제거** 리스크 |
| 강제력 총평 | 차단은 강하나 적용 범위·가시성 제약 큼 | 가시성·유연성 높으나 우회·정책 리스크 |

---

### 4.1 iOS 방식 — Screen Time(FamilyControls) 위임 모델

#### (A) 가장 큰 구조적 제약 — "내 앱은 무엇이 열렸는지 모른다"

iOS Screen Time API의 핵심은 **프라이버시 보존을 위해 모든 게 불투명(opaque)** 하다는 것이다.
- `FamilyActivityPicker`로 사용자가 차단할 앱을 고르면, 내 앱은 앱의 **번들 ID조차 받지 못한다.** `ApplicationToken`(불투명 토큰)만 받는다.
- 따라서 "도박앱이 지금 열렸다"를 내 앱 코드가 **직접 감지할 수 없다.** → **헬퍼 알림 파이프라인의 트리거를 앱 코드에서 만들 수 없다는 뜻.**
- 차단은 `ManagedSettingsStore`에 토큰을 넣으면 **OS가 알아서** 해당 앱 실행을 막는다(아이콘 흐림/실행 시 차단 화면). 내 앱은 그 순간을 통보받지 못한다.

**→ 설계 우회:** 직접 감지 대신 **DeviceActivityMonitor extension + 이벤트 임계값(threshold)** 으로 간접 감지한다. 특정 앱 사용 시간이 1초/임계 도달하면 `eventDidReachThreshold(_:activity:)` 콜백이 extension에서 울린다. 이를 차단 시도 신호로 간주해 App Group 공유 컨테이너 + 로컬 푸시/Darwin notification으로 메인 앱에 신호를 넘긴다.

#### (B) 권한 흐름 (FamilyControls Authorization)

```swift
import FamilyControls

let center = AuthorizationCenter.shared
do {
    // .individual: 본인 기기 자기통제 모드 (자녀 보호자 모드 아님)
    try await center.requestAuthorization(for: .individual)
    // 성공 시 center.authorizationStatus == .approved
} catch {
    // 사용자가 Screen Time 암호/Face ID 거부 → .denied
}
```

- `.individual` 모드: 도박 당사자가 **자기 자신을 통제**하는 시나리오에 적합.
- 차단 강도를 높이려면 `.child` 모드(보호자가 다른 기기 통제)도 검토 가능하나, 후원자 기기-당사자 기기 페어링(Family Sharing) 필요 → UX 복잡. **MVP는 `.individual` + 우회 시 헬퍼 알림으로 보완.**

#### (C) 차단 대상 선택 → 저장

```swift
import FamilyControls
import ManagedSettings

// 1) FamilyActivityPicker로 사용자가 앱/카테고리/웹도메인 선택
//    -> 결과는 FamilyActivitySelection (토큰 묶음, 불투명)
@State var selection = FamilyActivitySelection()
// FamilyActivityPicker(selection: $selection)  // SwiftUI

// 2) ManagedSettingsStore에 적용 → OS가 차단 집행
let store = ManagedSettingsStore(named: .init("dtx.gambling"))
store.shield.applications = selection.applicationTokens          // 앱 차단
store.shield.applicationCategories =
    .specific(selection.categoryTokens)                          // 카테고리 차단
store.shield.webDomains = selection.webDomainTokens             // 사파리 웹 차단

// 세션 종료/해제
store.shield.applications = nil
store.clearAllSettings()
```

- `shield.webDomains`는 **Safari 한정.** Chrome 등 서드파티 브라우저의 도박 사이트 접속은 막지 못한다(중대한 한계 → §4.3 권한표·한계에 명시).
- 클리닉용 도박앱 추천 블록리스트를 줄 수 없다(토큰 불투명). **사용자가 직접 picker에서 골라야 한다** → 온보딩에서 "주요 도박앱들을 직접 선택" 가이드 필요(Clinical&Safety가 스크린샷 가이드 제공).

#### (D) 모니터링 — DeviceActivity 스케줄/이벤트

```swift
import DeviceActivity

let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd:   DateComponents(hour: 23, minute: 59),
    repeats: true
)
// 임계값 이벤트: 선택된 앱을 1초라도 쓰면 콜백 → '접속 시도' 신호로 사용
let event = DeviceActivityEvent(
    applications: selection.applicationTokens,
    threshold: DateComponents(second: 1)
)
let dac = DeviceActivityCenter()
try dac.startMonitoring(.init("dtx.guard"),
                        during: schedule,
                        events: [.init("gamblingTouch"): event])
```

```swift
// DeviceActivityMonitor extension (별도 타깃, App Group 공유)
class GuardMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityName,
                                         activity: DeviceActivityName) {
        // ★ "도박앱 접근 시도" 간접 감지 지점 ★
        // 1) App Group UserDefaults에 이벤트 기록
        // 2) 강한 shield 재적용 (이중 방어)
        // 3) Darwin notification 또는 로컬 푸시로 메인 앱 깨우기
        //    -> 메인 앱이 Django에 BLOCK_ATTEMPT 보고 → 헬퍼 알림
    }
}
```

#### (E) 엔타이틀먼트·심사 제약 (현실 경고)

- `com.apple.developer.family-controls`는 **일반 개발자 계정에서 토글 불가.** 애플에 **별도 신청서**를 내고 "왜 필요한지(부모 통제/디지털 웰빙/중독 치료)"를 설명해 **수동 승인**을 받아야 한다. **거절되면 iOS 차단 기능 전체가 불가.** → 일정·리스크에 반드시 반영.
- App Store 심사: Screen Time API를 자기통제/웰빙 목적 외(광고·트래킹)로 쓰면 리젝. DTx·의료 목적이라 **명분은 좋지만**, 데이터 수집 최소화·목적 명시가 심사 통과의 핵심.
- DeviceActivityMonitor extension은 **메모리·실행시간 제약이 극도로 빡빡**(수 MB, 수 초). 무거운 네트워크 호출 금지 → App Group에 큐잉만 하고 메인 앱이 처리.

---

### 4.2 Android 방식 — 능동 감시·차단 모델

#### (A) AccessibilityService — 포그라운드 패키지 감지 → 오버레이 차단

```kotlin
class GuardAccessibilityService : AccessibilityService() {

    private val blocked = setOf(
        "com.gambling.app1", "com.gambling.app2", /* 블록리스트 */
    )

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val pkg = event.packageName?.toString() ?: return
            // 브라우저면 URL 노드 텍스트 검사로 도박 도메인까지 차단 가능
            if (pkg in blocked || isGamblingUrl(event)) {
                showBlockOverlay()                 // SYSTEM_ALERT_WINDOW 오버레이
                performGlobalAction(GLOBAL_ACTION_HOME) // 강제 홈 이동
                reportBlockAttempt(pkg)            // ★헬퍼 알림 트리거★
            }
        }
    }
    override fun onInterrupt() {}
}
```

- **iOS와 결정적 차이:** 패키지명·브라우저 URL을 **실시간으로 직접 본다** → 차단 시점·대상이 명확 → 헬퍼 알림 트리거를 앱 코드가 직접 만든다.
- 브라우저 도박 사이트: AccessibilityNodeInfo에서 주소창 텍스트를 읽어 도메인 매칭(Chrome/삼성인터넷 등 대응 가능, iOS가 못 하는 부분).

#### (B) Foreground Service — 상시 감시 생존성

```kotlin
class GuardForegroundService : Service() {
    override fun onStartCommand(i: Intent?, f: Int, id: Int): Int {
        startForeground(NOTIF_ID, buildPersistentNotification())
        // Heartbeat 타이머: 30초마다 서버에 ALIVE 핑 → 끊기면 서버가 '우회 의심'
        startHeartbeat()
        return START_STICKY  // 킬 당해도 OS가 재시작 시도
    }
}
```

- AccessibilityService가 시스템에 의해 종료되어도 FGS가 watchdog로 재바인딩 유도, 상태 핑 유지.
- **배터리 최적화 예외**(`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)를 받아야 Doze에서 살아남음 → 거부 시 우회 가능성↑ → 헬퍼에 "보호 약화" 통지.

#### (C) Google Play 정책 대응 (앱 제거 리스크)

- AccessibilityService를 **장애인 접근성 외 목적**으로 쓰면 Play 정책 위반. **단,** "사용자가 명시 동의한 부모통제/디지털웰빙/중독치료" 용도는 허용 예외에 해당.
- 필수 대응: ① Play Console에서 **AccessibilityService 사용 사유 선언(declaration)**, ② 앱 내 **명확한 고지 + 사용자 동의 화면**(왜 접근성 권한이 필요한지, 무엇을 하는지), ③ 프로미넌트 디스클로저. 누락 시 리젝/삭제.

---

### 4.3 권한 표 (플랫폼·권한·용도·획득 UX·거부 시 대안)

#### iOS

| 권한/엔타이틀먼트 | 용도 | 획득 UX | 거부/실패 시 대안 |
|---|---|---|---|
| `family-controls` 엔타이틀먼트 | Screen Time API 사용 자격 | **애플 사전 승인**(개발 단계) | 거절 시 iOS 차단 불가 → "셀프 약속 + 헬퍼 알림 only" 폴백 모드 |
| FamilyControls Authorization | 앱/웹 차단 권한 | 온보딩에서 `requestAuthorization`, Screen Time 암호 입력 | 거부 시 차단 불가 안내 + 후원자에게 "보호 미설정" 통지 |
| App Group | extension↔앱 데이터 공유 | 개발자 설정(사용자 무관) | 필수 |
| 알림 권한 | extension→앱 깨우기·헬퍼 푸시 | 표준 푸시 권한 팝업 | 거부 시 인앱 폴링으로 부분 대체 |

#### Android

| 권한 | 용도 | 획득 UX | 거부 시 대안 |
|---|---|---|---|
| AccessibilityService(`BIND_ACCESSIBILITY_SERVICE`) | 포그라운드 앱 감지·차단 | 설정 화면으로 딥링크 + 가이드 오버레이 | **거부 시 차단 핵심 불가** → 후원자에 "미보호" 통지, 사용통계 기반 사후 알림만 |
| `SYSTEM_ALERT_WINDOW` | 차단 오버레이 표시 | 설정 딥링크(`ACTION_MANAGE_OVERLAY_PERMISSION`) | 거부 시 오버레이 대신 강제 홈 이동만 |
| `PACKAGE_USAGE_STATS` | 사용통계 보조 감지 | 특수 설정 화면 안내 | 거부 시 Accessibility 단독 의존 |
| Foreground Service(`FOREGROUND_SERVICE` + 타입) | 상시 감시 | 자동(런타임 동의 불요, 상시 알림 노출) | — |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Doze 생존 | 시스템 다이얼로그 | 거부 시 우회 위험 통지 |
| `POST_NOTIFICATIONS`(A13+) | 상시·헬퍼 알림 | 런타임 권한 팝업 | 거부 시 FGS 알림만 |

---

### 4.4 차단 감지 → 헬퍼 알림 파이프라인

```
[로컬 차단 이벤트]
 iOS: DeviceActivityMonitor.eventDidReachThreshold → App Group 큐 → 메인 앱
 AND: AccessibilityService.onAccessibilityEvent (즉시)
        │
        ▼  EventChannel('dtx/blocker/events')  {type: BLOCK_ATTEMPT, ts, platform, meta}
[Flutter 레이어]
        │  POST /events/block-attempt  (JWT)  — 오프라인이면 로컬 큐 후 재전송
        ▼
[Django REST]
        │  규칙 판정(Clinical&Safety 규칙): 단순 알림 vs 위기 에스컬레이션
        ├──► FCM / APNs 푸시  → 후원자 앱("OO님이 도박앱 접근을 시도했습니다")
        ├──► SMS(후원자·가족)        — 서버측 SMS 게이트웨이
        └──► 전화연결 팝업/1336 안내  — 위기 임계 도달 시
```

**오프라인/킬드 상태 대비:**
- 로컬 이벤트는 **항상 먼저 디바이스 로컬 DB에 영속화**(WAL) → 네트워크 복구 시 재전송.
- **Heartbeat/Watchdog:** 앱이 30~60초 주기로 서버에 ALIVE 핑. 서버가 N분 이상 핑 부재 감지 → **"보호 비활성 의심"** 으로 간주, 후원자에게 능동 통지(앱 강제종료·전원 OFF·권한 회수 시나리오 커버). **이게 우회 방지의 핵심**: 차단을 뚫어도 "조용히 뚫리지 않는다."

### 4.5 우회 방지 매트릭스

| 우회 시도 | 감지 방법 | 헬퍼 통지 |
|---|---|---|
| 앱 강제종료 | 서버 Heartbeat 부재 | "보호 중단됨" 푸시/SMS |
| 권한 회수(접근성/Screen Time off) | 주기적 권한 상태 체크 → REVOKED 이벤트 | "보호 권한 해제됨" |
| 차단 세션 임의 종료 | 세션 변경 감사 로그 | "세션 조기 종료" |
| 기기 전원 OFF/비행기모드 | Heartbeat 부재 + 마지막 위치/시각 | "기기 오프라인 장기화" |
| 앱 삭제 | 서버측 디바이스 토큰 영구 무응답 | "앱 제거 의심" |

### 4.6 프라이버시 (최소수집 원칙)

- **수집:** 차단 이벤트 메타데이터(타임스탬프, 플랫폼, 차단됨/시도 여부, 카테고리 수준). **미수집:** 화면 내용, 입력 텍스트, 일반 앱 사용 이력, URL 전문(도박 도메인 매칭 결과 boolean만).
- iOS는 구조상 토큰만 다루므로 프라이버시 친화적(앱 ID조차 모름). Android는 능동 감시이므로 **블록리스트 매칭 결과만 기록**하고 비대상 앱 정보는 즉시 폐기.
- 후원자에게 가는 알림도 "도박앱 접근 시도" 사실만, 어떤 앱인지 상세는 최소화(Clinical&Safety와 문구 합의).

---

## 5. 핸드오프 체크리스트

**→ System Architect**
- [ ] iOS 차단 강제력 한계(브라우저·토큰 불투명·권한 회수) 리스크 등재 확인
- [ ] Heartbeat 주기·서버 타임아웃 임계값 합의
- [ ] MethodChannel/EventChannel 계약 동결

**→ Backend/Data**
- [ ] `/events/block-attempt`, `/events/tamper`, `/heartbeat` 엔드포인트 스키마 합의
- [ ] FCM/APNs 토큰 등록·후원자 매핑·SMS/전화 트리거 규칙 연동
- [ ] 오프라인 재전송 멱등성(idempotency key) 보장

**→ Frontend/UX**
- [ ] 권한 온보딩 흐름(특히 Android 접근성 딥링크, iOS Screen Time 암호) 화면 설계
- [ ] 차단 오버레이·1336 전화연결 팝업 위젯, 권한 거부 폴백 안내
- [ ] 권한 상태 enum(`granted/denied/revoked/partial`) 바인딩

**→ Clinical&Safety**
- [ ] 도박앱·도메인 블록리스트 제공 + iOS용 "직접 선택" 온보딩 가이드(스크린샷)
- [ ] 위기 에스컬레이션 임계(단순 알림 vs 1336 전화) 규칙 정의
- [ ] 후원자 알림 문구·프라이버시 노출 수준 합의

**→ 운영/법무(에스컬레이션)**
- [ ] 애플 `family-controls` 엔타이틀먼트 신청·승인 일정 확보(블로커 리스크)
- [ ] Google Play AccessibilityService 사용 사유 선언·프로미넌트 디스클로저 준비

---
*문서 책임: Native Integration 서브에이전트 · 최종 갱신 2026-06-18*
