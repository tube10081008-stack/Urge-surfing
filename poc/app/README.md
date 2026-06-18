# 마음 파도타기 — 도박중독 DTx PoC (Flutter 프론트엔드, P0)

도박 충동을 억누르지 않고 "파도처럼 지나가도록" 함께 연습하는 디지털 치료제(DTx)
프로토타입의 **P0 PoC 프론트엔드**입니다. 노출(Exposure) → 충동 파도타기(Urge
Surfing) → VAS(갈망) 사전/사후 기록 → 결과 전송까지의 단일 흐름을 구현합니다.

> 인증/차단 기능은 P0 범위 밖이며, 노출 미디어는 실제 바이너리 없이 **플레이스홀더**로
> 시뮬레이션합니다(전체화면 색배경 + "재생 중…" + 잔여시간 + 중단버튼).

## 기술 스택

- Flutter (SDK `>=3.0.0`)
- 상태관리: `flutter_riverpod`
- 네트워크: `http`

## 실행 방법

```bash
# 1) 의존성 설치
flutter pub get

# 2) (선택) 백엔드 주소 설정
#    기본값: http://localhost:8000/api/v1
#    lib/api/api_client.dart 의 ApiClient.baseUrl 상수를 환경에 맞게 수정합니다.
#    - iOS 시뮬레이터 / 데스크톱 / 웹 : http://localhost:8000/api/v1
#    - Android 에뮬레이터            : http://10.0.2.2:8000/api/v1

# 3) 실행
flutter run
```

> 백엔드가 꺼져 있어도 데모는 동작합니다(노출 자극 폴백 1종 제공). 다만 VAS/결과
> 전송은 실패 메시지만 표시되고 화면 흐름은 계속 진행됩니다.

## 백엔드 API 계약 (base: `http://localhost:8000/api/v1`)

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/exposure-media` | 노출 자극 목록 |
| POST | `/training-sessions` | 세션 생성 (`session_type`, `media_id?`) |
| PATCH | `/training-sessions/{id}` | 세션 완료 (`completed:true`) |
| POST | `/training-sessions/{id}/vas` | VAS 기록 (`phase`, `vas_value`) |
| POST | `/urge-surfing` | 파도타기 결과 전송 |

## 화면 흐름 (5개 화면)

1. **홈** (`home_screen.dart`)
   오늘의 노출 자극 안내 → `[세션 시작]`. 세션 생성(POST /training-sessions).
2. **사전 VAS** (`vas_input_screen.dart`, phase: pre)
   0~10 슬라이더로 현재 갈망 입력 → POST /vas (phase=pre).
3. **노출** (`exposure_screen.dart`)
   플레이스홀더 노출 화면. 60초 자동 cap + 중단 버튼.
4. **충동 파도타기** (`urge_surfing_screen.dart`) — **핵심**
   3분 타이머. 파도 애니메이션(점점 잔잔해짐) + 4-7-8 호흡 가이드 + 실시간 코칭 자막.
5. **사후 VAS** (`vas_input_screen.dart`, phase: post)
   다시 0~10 입력 → POST /vas (phase=post).
6. **결과** (`result_screen.dart`)
   사전/사후 비교, outcome 자동 판정(success/relapse), 결과 전송
   (POST /urge-surfing + PATCH 완료).

> 모든 화면에 **SOS 버튼(도움요청 1336)**이 상시 노출됩니다.

## 핵심 애니메이션 구현

### 파도 (`lib/widgets/wave_painter.dart`)
- `WavePainter`(CustomPainter): 서로 다른 진폭/주파수/위상을 가진 **사인파 3겹**을
  겹쳐 바다 느낌을 냅니다.
- `AnimationController`(`WaveAnimation`)가 `phase`를 4초 주기로 반복시켜 파도가 옆으로
  흐릅니다.
- 세션 진행도 `progress`(0→1)에 따라 진폭 비율이 **1.0 → 0.15로 선형 감쇠**합니다.
  → "충동도 시간이 지나면 잦아든다"는 은유를 시각화.

### 호흡 가이드 (`lib/widgets/breathing_guide.dart`)
- **4-7-8 호흡**: 들이쉬기 4초 → 멈추기 7초 → 내쉬기 8초 (한 사이클 19초 반복).
- `AnimationController`로 원의 지름이 확장/수축하며, 현재 단계 라벨과 카운트다운을
  중앙에 표시합니다.

## 프로젝트 구조

```
app/
├── pubspec.yaml
├── README.md
└── lib/
    ├── main.dart                       # ProviderScope + MaterialApp + 홈 라우팅
    ├── api/
    │   └── api_client.dart             # http 클라이언트 (baseUrl 상수)
    ├── models/
    │   ├── exposure_media.dart
    │   ├── training_session.dart
    │   └── vas_record.dart
    ├── state/
    │   └── session_controller.dart     # Riverpod StateNotifier
    ├── screens/
    │   ├── home_screen.dart
    │   ├── vas_input_screen.dart        # pre/post 공용
    │   ├── exposure_screen.dart
    │   ├── urge_surfing_screen.dart      # 핵심 화면
    │   └── result_screen.dart
    └── widgets/
        ├── wave_painter.dart            # 사인파 + 진폭 감쇠 CustomPainter
        ├── breathing_guide.dart         # 4-7-8 호흡 애니메이션
        ├── vas_slider.dart              # 0~10 슬라이더
        └── sos_button.dart              # 도움요청 1336 (상시)
```

## 디자인 원칙

- **비낙인·차분한 톤**: 청록 계열, "잘하고 못하고는 없다"는 메시지.
- **SOS 상시 노출**: 모든 화면에서 1336(한국도박문제예방치유원) 접근 가능.
- 한국어 UI / 한국어 코드 주석.
