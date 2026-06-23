# Live Translate PoC — 중국에서 쓰는 실시간 음성 통역

Google **Gemini 3.5 Flash Live Translate**(실시간 음성→음성 번역)를 이용한
풀스택 PoC. 중국 본토처럼 구글이 차단된 환경에서 현지인과 음성으로 소통하는
것이 목표다.

> ⚠️ 이 모듈은 본 레포의 충동 서핑(치료) 앱과 **무관한 독립 PoC**다.
> `poc/livetranslate/` 안에 자기완결적으로 들어 있다.

## 왜 릴레이가 필요한가

Gemini Live API의 실제 엔드포인트는 구글 도메인이다:

```
wss://generativelanguage.googleapis.com/ws/...BidiGenerateContent?key=...
```

중국 본토에서는 **만리방화벽(GFW)** 이 이 도메인을 차단한다. 따라서 폰 앱이
구글에 *직접* 붙는 구조는 동작하지 않는다. 대신 **중국 밖**에 릴레이를 두고,
폰은 릴레이에만 연결한다.

```
[중국 내 Flutter 앱]
      │  ① 내 WebSocket (PCM16 오디오 양방향)
      ▼
[해외 VPS 릴레이 (FastAPI)]      ← 도쿄/싱가포르 등 구글 되는 리전
      │  ② Gemini Live API WebSocket (API 키는 여기에만 보관)
      ▼
[Google Gemini 3.5 Live Translate]
```

- 입력 오디오: PCM16, **16kHz**, mono, little-endian
- 출력 오디오: PCM16, **24kHz**, mono (Gemini가 내려주는 그대로 재생)
- API 키는 릴레이 서버에만 존재 → 폰에 노출되지 않음

## 구성

```
poc/livetranslate/
├── relay/                  # FastAPI 릴레이 서버 (해외 배포)
│   ├── main.py
│   ├── requirements.txt
│   └── .env.example
└── app/                    # Flutter 클라이언트 (폰)
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── translate_screen.dart
        └── translate_service.dart
```

## 실행

### 1) 릴레이 서버 (중국 밖에서 구동)

```bash
cd poc/livetranslate/relay
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # GEMINI_API_KEY, RELAY_TOKEN 채우기
python main.py              # 0.0.0.0:8080
# 헬스체크: curl http://localhost:8080/health
```

#### Docker로 배포 (해외 VPS 권장)

```bash
cd poc/livetranslate/relay
cp .env.example .env        # 키/토큰 채우기
docker compose up -d --build
# 헬스체크: curl http://localhost:8080/health
```

#### 테스트

실제 키 없이 구글 업스트림을 모킹해 중계 로직(setup 포맷·양방향 오디오·토큰
검사)을 검증한다.

```bash
cd poc/livetranslate/relay
pip install -r requirements.txt httpx pytest
pytest -q                   # 3 passed
```

### 2) Flutter 앱

릴레이 주소/토큰을 `--dart-define` 으로 주입한다.

```bash
cd poc/livetranslate/app
flutter pub get
flutter run \
  --dart-define=RELAY_BASE_URL=wss://my-relay.example.com \
  --dart-define=RELAY_TOKEN=change-me
```

로컬 테스트(안드로이드 에뮬레이터 ↔ 로컬 릴레이)는 기본값
`ws://10.0.2.2:8080` 을 그대로 쓰면 된다.

### 플랫폼 권한

- **Android** `android/app/src/main/AndroidManifest.xml`
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  ```
- **iOS** `ios/Runner/Info.plist`
  ```xml
  <key>NSMicrophoneUsageDescription</key>
  <string>실시간 통역을 위해 마이크를 사용합니다.</string>
  ```

## 중국에서 실제로 쓰기 — GFW 통과 (가장 중요)

릴레이를 해외에 둬도, **폰 → 릴레이** 연결 자체가 GFW를 지난다. 신뢰도 순:

1. **(권장) VPS에 프록시 + 터널링** — VPS에 Shadowsocks / V2Ray / Trojan /
   Hysteria2 를 띄우고 폰 트래픽을 터널링. 그러면 릴레이(또는 구글 직결)가
   사실상 안정적으로 살아남는다.
2. **내 도메인 + 443/WSS 직결** — 신규 VPS IP면 종종 되지만 SNI 필터·스로틀로
   불안정할 수 있다.
3. 릴레이는 **지리적으로 가까운 리전(일본/싱가포르)** 에 둘 것. 홉이 늘수록
   실시간 통역 체감이 나빠진다.

### 반드시 출국 전에
- 릴레이/프록시/앱을 한국에서 **미리 구축·테스트**한다. 현지에서는 프록시
  다운로드·접속 자체가 막힌다.
- 백업으로 오프라인 번역(구글 번역 오프라인팩, 바이두 번역 등)을 깔아둔다.
- ⚠️ 중국 내 무허가 VPN/프록시 사용은 **법적 회색지대**다. 리스크를 감안할 것.

## 한계 / 미검증

- 본 PoC는 **코드 산출물** 위주다. 이 환경에는 Flutter SDK와 유효한 Gemini
  API 키가 없어 **엔드투엔드 실행 검증은 하지 못했다.** 릴레이는 파이썬 문법
  검증만 수행.
- `gemini-3.5-live-translate-preview` 는 **미리보기** 모델이라 필드/모델명이
  바뀔 수 있다. 동작이 이상하면 `relay/.env` 의 `GEMINI_LIVE_MODEL` 과
  `main.py` 의 setup 메시지를 최신 공식 문서와 대조할 것.
- `flutter_sound` 의 스트림 재생 API(`foodSink`/`startPlayerFromStream`)는
  버전에 따라 시그니처가 달라질 수 있다.

## 참고

- Live translation with Gemini Live API — https://ai.google.dev/gemini-api/docs/live-api/live-translate
- Gemini Live API (WebSockets) — https://ai.google.dev/gemini-api/docs/live-api/get-started-websocket
- Live API reference — https://ai.google.dev/api/live
