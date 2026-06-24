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
    ├── setup.sh            # 플랫폼 폴더 생성 + 권한 주입 자동화
    └── lib/
        ├── main.dart
        ├── translate_screen.dart   # 양방향 대화 UI
        ├── settings.dart           # 릴레이/언어 설정 저장
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

#### Fly.io 배포 (도쿄 리전, 자동 wss — 여행용 권장)

로컬 Docker 없이 원격 빌드로 배포된다. wss 주소와 TLS가 자동 제공된다.

```bash
# 1) flyctl 설치 후 로그인
#    macOS:  brew install flyctl
#    Win:    iwr https://fly.io/install.ps1 -useb | iex
#    Linux:  curl -L https://fly.io/install.sh | sh
fly auth login

# 2) 릴레이 폴더에서 (fly.toml의 app 이름을 유일한 값으로 먼저 수정)
cd poc/livetranslate/relay
fly apps create <유일한-앱이름>     # fly.toml의 app 과 동일하게

# 3) 비밀값 주입(코드/저장소에 키를 넣지 않음)
fly secrets set GEMINI_API_KEY=새-Gemini-키 RELAY_TOKEN=원하는토큰 --app <앱이름>

# 4) 원격 빌드·배포
fly deploy --remote-only --app <앱이름>

# 5) 확인
curl https://<앱이름>.fly.dev/health
```

앱에는 **`wss://<앱이름>.fly.dev`** 를 릴레이 주소로 입력한다(토큰도 동일하게).
여행 중 콜드스타트를 피하려면 `fly.toml` 의 `min_machines_running` 을 1로.

#### 테스트

실제 키 없이 구글 업스트림을 모킹해 중계 로직(setup 포맷·양방향 오디오·토큰
검사)을 검증한다.

```bash
cd poc/livetranslate/relay
pip install -r requirements.txt httpx pytest
pytest -q                   # 3 passed
```

### 2) Flutter 앱

이 PoC는 `lib/` 와 `pubspec.yaml` 만 포함한다. 빌드 전에 플랫폼 폴더
(android/ios) 생성과 마이크/인터넷 권한 주입이 필요한데, **`setup.sh`** 가
이를 자동화한다(여러 번 실행해도 안전).

```bash
cd poc/livetranslate/app
./setup.sh        # flutter create + 권한 주입 + pub get

# 안드로이드 에뮬레이터 ↔ 같은 PC의 로컬 릴레이 (기본값 ws://10.0.2.2:8080)
flutter run

# 실기기(같은 와이파이) → PC LAN IP
flutter run --dart-define=RELAY_BASE_URL=ws://192.168.0.x:8080

# 해외 릴레이(운영)
flutter run \
  --dart-define=RELAY_BASE_URL=wss://my-relay.example.com \
  --dart-define=RELAY_TOKEN=설정한토큰

# APK 빌드
flutter build apk --release \
  --dart-define=RELAY_BASE_URL=wss://my-relay.example.com \
  --dart-define=RELAY_TOKEN=설정한토큰
```

> `setup.sh` 가 주입하는 권한: Android `INTERNET`/`RECORD_AUDIO`,
> iOS `NSMicrophoneUsageDescription`. 빌드가 minSdk 관련으로 실패하면
> `android/app/build.gradle(.kts)` 의 `minSdkVersion` 을 24 로 올린다
> (flutter_sound 요구사항).

> ℹ️ **대화 모드(양방향, 푸시투토크)**: 화면이 위/아래 두 칸으로 나뉜다.
> 위 칸은 180° 회전되어 맞은편 상대가 똑바로 본다. **자기 칸을 누르고 있는
> 동안만** 말하고, 손을 떼면 상대 언어 음성으로 통역된다. 누르는 동안만
> 마이크가 켜지므로, 스피커로 나온 번역 음성이 마이크로 되돌아가 **직전 말이
> 반복되는 피드백을 방지**한다. 방향 전환 시 마이크는 유지하고 세션만 빠르게
> 재연결한다.
>
> ℹ️ **상대 배려**: 각 칸의 안내 문구는 그 칸을 쓰는 사람의 언어로 표시된다
> (예: 상대 칸은 중국어 `按住说话`). 언어 이름은 자기 언어 표기(autonym)로
> 보여 누구나 알아본다.
>
> ℹ️ 릴레이 주소/토큰과 언어쌍은 우측 상단 **⚙ 설정**에서 입력하며
> 기기에 저장된다(한 번만 설정). cloudflared처럼 주소가 바뀌어도 APK 재빌드
> 없이 설정만 바꾸면 된다. **"재연결 중…"에서 멈춘다면** 설정의 릴레이 주소가
> 실제 동작하는 릴레이(`/health`가 200·`key_configured:true`)를 가리키는지,
> 토큰이 일치하는지 확인할 것.

> ℹ️ 현재 Live Translate 설정(`responseModalities: AUDIO`)은 **번역 음성만**
> 반환하고 텍스트 자막은 내려주지 않는다(실측). 따라서 화면의 자막 영역은
> 보통 비어 있으며, 통역은 **음성으로 재생**된다.

#### 로컬 Flutter 없이 빌드 — GitHub Actions

`.github/workflows/build-livetranslate-apk.yml` 가 클라우드에서 APK를 빌드한다.

1. GitHub → **Actions → Build Live Translate APK → Run workflow**.
2. `relay_base_url` 에 운영 릴레이 주소(`wss://...`) 입력.
3. 릴레이 토큰은 저장소 **Settings → Secrets → Actions** 에 `RELAY_TOKEN`
   으로 등록하면 빌드에 주입된다(없으면 빈 값).
4. 완료 후 실행 페이지 하단 **Artifacts → `livetranslate-apk`** 다운로드.

> release APK는 기본 debug 키로 서명되어 **테스트 설치용**이다. 스토어 배포용
> 서명은 별도 keystore 설정이 필요하다. `poc/livetranslate/app/**` 푸시 시에도
> 자동 빌드된다.

## 부가 기능 (하단 바)

- **⭐ 문구**: 자주 쓰는 여행 문구를 탭하면 상대 언어로 번역해 음성 출력
  (릴레이 `/speak`: 텍스트 번역 + Gemini TTS).
- **📷 카메라 번역**: 메뉴판·간판을 촬영하면 텍스트 인식 + 내 언어 번역
  (릴레이 `/ocr`: Gemini 비전). 결과 다이얼로그에서 "들려주기"로 음성 재생.
- **🔁 다시듣기**: 직전 통역 음성을 다시 재생.
- **💱 도우미**: 환율 환산(릴레이 `/rate`, 무료 공개 API·1h 캐시·앱 측 마지막값
  오프라인 폴백)과 흥정 문장 생성(릴레이 `/bargain`: 제안 가격 → 대상 언어
  흥정 문장 + TTS).

> ⚠️ `/speak`·`/ocr` 는 릴레이의 **새 엔드포인트**다. 기존 배포본에는 없으니
> 이 기능을 쓰려면 **릴레이를 재배포**해야 한다(`fly deploy` 등). 두 엔드포인트는
> 텍스트/비전/TTS REST 모델(`GEMINI_TEXT_MODEL`=gemini-2.5-flash,
> `GEMINI_TTS_MODEL`=gemini-2.5-flash-preview-tts)을 쓰며, 같은 API 키로 동작한다.

## 네트워크 복원력 (중국 환경 대비)

GFW는 TCP 연결은 살려둔 채 데이터만 조용히 끊는(throttle/blackhole) 경우가
잦다. 이를 견디도록 앱·릴레이에 다음을 넣었다.

- **하트비트(ping/pong)**: 앱이 10초마다 `{"type":"ping"}` 전송, 릴레이가
  즉시 `{"type":"pong"}` 응답.
- **워치독**: 20초간 수신(오디오/자막/pong 무엇이든)이 없으면 죽은 연결로
  보고 강제 재연결.
- **지수 백오프 자동 재연결**: 1s→2s→…→최대 30s(+지터). 재연결 중에도
  마이크/플레이어는 유지하고 소켓만 복구하며, 화면에 `재연결 중…` 표시.
- **업스트림 keepalive**: 릴레이↔구글 WebSocket에 `ping_interval=20`,
  `ping_timeout=20` 적용해 죽은 업스트림을 빨리 끊는다.

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

## 검증 상태

- ✅ **릴레이 ↔ Gemini 전 구간 실측 검증 완료.** 실제 API 키로 한국어 음성
  4.5초를 릴레이에 흘려보내 영어/중국어 번역 음성을 수신했다. 수신 음성을
  다시 전사한 결과:
  - 한→영: `Hello, it's nice to meet you.`
  - 한→중: `你好,很高興見到你。`
- ✅ 유닛 테스트(setup 포맷·양방향 오디오·ping/pong·토큰·헬스체크) 4 passed.
- ⚠️ **Flutter UI 계층은 미검증** — 이 개발 환경에 Flutter SDK가 없어 앱
  컴파일/실행은 못 했다. `flutter_sound` 의 스트림 재생 API
  (`foodSink`/`startPlayerFromStream`)는 버전에 따라 시그니처가 다를 수 있다.
- ⚠️ `gemini-3.5-live-translate-preview` 는 **미리보기** 모델이다. 입력 언어는
  자동 감지되며, `translationConfig` 는 `sourceLanguageCode` 를 받지 않는다
  (실측 확인). 모델/필드가 바뀌면 `relay/.env` 의 `GEMINI_LIVE_MODEL` 과
  `main.py` 의 setup 메시지를 최신 문서와 대조할 것.

## 참고

- Live translation with Gemini Live API — https://ai.google.dev/gemini-api/docs/live-api/live-translate
- Gemini Live API (WebSockets) — https://ai.google.dev/gemini-api/docs/live-api/get-started-websocket
- Live API reference — https://ai.google.dev/api/live
