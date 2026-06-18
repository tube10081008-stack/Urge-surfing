# 🚀 배포 가이드 (Deployment)

> P0 PoC를 **실제 앱처럼 배포**하기 위한 구성. 두 갈래: ① Android APK 자동 빌드, ② 백엔드 운영 배포(Docker).
> ⚠️ PoC는 인증·차단·암호화 미적용이므로 **실환자·실데이터 금지**(로컬/내부 테스트 전용). 운영 승격 경로는 본 문서 말미 참조.

---

## ① Android APK 자동 빌드 (GitHub Actions)

앱(`poc/app`)에는 `android/` 플랫폼 폴더가 없어서, CI가 `flutter create`로 생성한 뒤 빌드한다.

### 실행 방법
1. GitHub 저장소 → **Actions** 탭 → **Build Android APK** 워크플로우
2. **Run workflow** 클릭 → (선택) `api_base_url` 입력
   - 같은 기기 로컬 백엔드: 안드로이드 에뮬레이터는 `http://10.0.2.2:8000/api/v1`
   - 운영 백엔드: `https://<배포도메인>/api/v1`
3. 완료 후 하단 **Artifacts → `dtx-gambling-apk`** 다운로드 → 기기에 설치(사이드로드)

### 자동 트리거
- `poc/app/**` 또는 워크플로우 파일 변경을 `main`/`claude/**` 브랜치에 push하면 자동 빌드.

### 서명에 대한 현실 고지
- 워크플로우는 `flutter build apk --release`로 빌드하며, Flutter 기본 템플릿은 **release를 debug 키로 서명**한다 → **사이드로드 설치/테스트는 가능**하지만 **Play 스토어 업로드는 불가**.
- Play 스토어 출시 시: 업로드 키스토어 생성 → `android/key.properties` + `signingConfigs` 구성 → AAB(`flutter build appbundle`) 빌드. (키스토어는 GitHub Secrets로 주입, 저장소에 커밋 금지)

### 앱 ↔ 백엔드 주소 주입
- 코드에 하드코딩하지 않고 빌드 시 주입: `--dart-define=API_BASE_URL=...`
- `ApiClient.baseUrl`이 `String.fromEnvironment('API_BASE_URL')`로 이 값을 읽음.

---

## ② 백엔드 운영 배포 (Docker)

`config/settings.py`는 **환경변수가 없으면 PoC(SQLite/DEBUG), 있으면 운영(PostgreSQL/보안 강화)** 으로 자동 전환된다.

### 로컬에서 운영 유사 실행 (PostgreSQL 포함)
```bash
cd poc/backend
docker compose up --build
# → http://localhost:8000/api/v1/exposure-media
```

### 단일 이미지 빌드/실행
```bash
cd poc/backend
docker build -t dtx-backend .
docker run -p 8000:8000 \
  -e DJANGO_SECRET_KEY="$(openssl rand -hex 32)" \
  -e DJANGO_DEBUG=False \
  -e DJANGO_ALLOWED_HOSTS="your-domain.com" \
  -e DATABASE_URL="postgres://user:pass@host:5432/db" \
  dtx-backend
```
> 컨테이너 시작 시 `entrypoint.sh`가 migrate → seed → gunicorn 순으로 기동.

### 환경변수 (전체 목록: `.env.example`)
| 변수 | 용도 | 예시 |
|---|---|---|
| `DJANGO_SECRET_KEY` | **필수.** 세션/서명 키 | 랜덤 64자 |
| `DJANGO_DEBUG` | 운영은 `False` | `False` |
| `DJANGO_ALLOWED_HOSTS` | 허용 호스트(콤마) | `api.example.com` |
| `DATABASE_URL` | 있으면 PostgreSQL | `postgres://u:p@h:5432/db` |
| `CORS_ALLOWED_ORIGINS` | 허용 출처(콤마) | `https://app.example.com` |
| `DJANGO_CSRF_TRUSTED_ORIGINS` | CSRF 신뢰 출처 | `https://api.example.com` |
| `DJANGO_SECURE_SSL_REDIRECT` | HTTPS 강제 | `True` |

### 호스팅 (범용 Docker)
이 이미지는 특정 업체에 종속되지 않으므로 **Docker를 받는 어떤 곳에든** 올릴 수 있다:
- **Railway / Render / Fly.io**: 저장소 연결 또는 이미지 푸시 → 위 환경변수 주입 → PostgreSQL 애드온 연결(`DATABASE_URL` 자동/수동)
- **직접 VM**: `docker compose up -d` + 앞단에 Nginx/Caddy로 TLS 종단
- 헬스체크 경로: `GET /api/v1/exposure-media` (Dockerfile HEALTHCHECK 내장)

---

## 운영 승격 시 남은 작업 (PoC → Production)
현재 배포 구성은 "돌아가는 PoC를 안전하게 띄우는" 수준까지다. 정식 DTx 출시 전 필요한 것:
- 🔐 **인증/RBAC**(JWT), UUID PK, 환자-치료자 분리 → [`agents/backend-data.md`](../agents/backend-data.md)
- 📱 **App Blocker 네이티브 레이어**(iOS Screen Time / Android Accessibility) → [`agents/native-integration.md`](../agents/native-integration.md)
- 🩺 **임상·규제**(식약처, 1336 위기대응) → [`agents/clinical-safety.md`](../agents/clinical-safety.md)
- 🗄️ **TimescaleDB** 시계열 로깅, 임상 대시보드(React)
- 🍎 **앱 서명/스토어 출시**(Apple `family-controls` 엔타이틀먼트 사전 승인 필수)

→ 상위: [프로젝트 README](../README.md) · [PoC README](./README.md)
