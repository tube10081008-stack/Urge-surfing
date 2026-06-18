# 🗄️ Backend/Data — DB 스키마·DTx 대시보드 API
> 소속: DTx 도박중독 오케스트라 | 보고: Orchestrator

---

## 1. 정체성 & 임무

| 항목 | 내용 |
|---|---|
| **역할** | 도박중독 디지털치료제(DTx) 앱의 **백엔드/데이터 책임 서브에이전트** |
| **한 줄 임무** | 환자 훈련 데이터(ERP·충동 파도타기·VAS)를 **무결하고 추적가능하게** 저장하고, 임상가용 대시보드가 소비할 **신뢰성 있는 API와 성과지표**를 제공한다 |
| **핵심 가치** | 규제 적격성(식약처 디지털치료기기 심사 대응) · 데이터 무결성 · 민감정보(건강정보) 보호 · 임상 근거(evidence) 생성 |
| **기술 스택** | Django REST Framework + PostgreSQL + **TimescaleDB**(시계열 VAS) / SimpleJWT(JWT)+RBAC / AES-256(at rest)·TLS / React 대시보드 / CDN+서명URL / FCM·APNs·SMS(1336·후원자) |

본 문서는 **지침서이자 설계 산출물**이다. 후속 구현은 본 스키마/API 계약을 단일 진실 공급원(SSOT)으로 삼는다.

---

## 2. 책임 범위

**담당 (In Scope)**
- PostgreSQL/TimescaleDB **DB 스키마 설계 및 마이그레이션 정책** (DDL, 인덱스, 파티셔닝, 보존정책)
- DRF 기반 **REST API 설계**(환자앱용 + 임상 대시보드용), 인증/인가(RBAC), 직렬화 계약
- **DTx 치료성과 지표 정의 및 산출 쿼리**(VAS 변화추이, 충동 파도타기 성공률, 교육 진도율, 활동 수행 횟수)
- **데이터 거버넌스**: 암호화·익명화·보존기간·동의관리·감사추적(audit log)
- **오프라인→서버 동기화·멱등성·데이터 무결성** 설계

**비담당 (Out of Scope — 협업 의존)**
- 모바일 클라이언트 로컬 DB/큐 구현 → Native Integration
- 대시보드 UI/차트 렌더링 → Frontend/UX
- 인프라 프로비저닝·KMS·네트워크 보안 정책 확정 → System Architect
- 임상 프로토콜·알림 임계치·안전기준 정의 → Clinical & Safety

---

## 3. 협업 인터페이스

| 대상 에이전트 | 내가 받는 입력(Input) | 내가 주는 산출(Output) |
|---|---|---|
| **System Architect** | 배포 토폴로지, KMS/HSM 키 관리, VPC/TLS 정책, TimescaleDB 운영 사양 | DB 자원 요구사항(파티셔닝·보존), 마이그레이션 계획, 백업/복구 RPO·RTO 요구 |
| **Frontend/UX (React 대시보드)** | 화면별 데이터 요구(필터·기간·집계 단위), 차트 스펙 | 대시보드 API 계약(OpenAPI), 집계 엔드포인트, 페이지네이션/캐싱 규약 |
| **Native Integration (모바일)** | 오프라인 이벤트 스키마, 디바이스/푸시 토큰, 차단(blocking) 이벤트 페이로드 | 동기화 API(`/sync`), 멱등성 키 규약, 서명URL 발급 API, FCM/APNs 등록 API |
| **Clinical & Safety** | ERP 프로토콜·VAS 척도 정의, 위기 임계치(알림 트리거), 동의서 항목, 보존기간 규정 | 지표 산출 로직 검증본, 알림 로그 스키마, 감사추적 적합성 리포트 |

**계약 형식**: OpenAPI 3.1 스펙 + 본 DDL. 변경 시 시맨틱 버전(`/api/v1`)과 마이그레이션 노트 동반.

---

## 4. 산출물 (★핵심★)

### 4.1 데이터 모델 개요 (ERD 서술)

```
auth_users ──1:1── patients ──┬──< training_sessions ──< vas_records
                              │                       └──< urge_surfing_sessions
                              ├──< craving_timeseries  (TimescaleDB hypertable)
                              ├──< blocking_events
                              ├──< education_progress >── education_contents
                              ├──< alerts
                              ├──< consents
                              └──< patient_supporters >── supporters
clinicians ──< clinician_patient (배정) >── patients
exposure_media ──< training_sessions (자극 참조)
audit_log  (전 테이블 횡단, append-only)
```

---

### 4.2 PostgreSQL DDL (핵심 테이블)

> 공통 규약: PK는 `BIGSERIAL` 또는 `UUID`(외부노출·동기화 대상은 UUID). 모든 임상 테이블에 `created_at/updated_at TIMESTAMPTZ`, soft-delete용 `deleted_at`. 민감 컬럼은 `pgcrypto` 또는 앱계층 AES-256 봉투암호화(컬럼 주석 `-- 🔒 encrypted`).

```sql
-- 1) 인증 사용자 (RBAC 루트)
CREATE TYPE user_role AS ENUM ('patient','clinician','admin');
CREATE TABLE auth_users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         CITEXT UNIQUE NOT NULL,           -- 🔒 (로그인 식별자)
    password_hash TEXT NOT NULL,                     -- Argon2id
    role          user_role NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    mfa_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    last_login_at TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2) 환자 (가명처리 식별자 분리 저장)
CREATE TABLE patients (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL UNIQUE REFERENCES auth_users(id) ON DELETE RESTRICT,
    pseudonym_code  TEXT NOT NULL UNIQUE,             -- 임상분석용 가명코드 (예: PT-2026-00031)
    display_name    TEXT,                             -- 🔒
    birth_year      SMALLINT,                         -- 생년월일 대신 출생연도(최소수집)
    sex             CHAR(1) CHECK (sex IN ('M','F','O')),
    enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    program_stage   SMALLINT NOT NULL DEFAULT 1,      -- ERP 단계
    status          TEXT NOT NULL DEFAULT 'active',   -- active/paused/discharged
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);

-- 3) 임상가(의사·상담사)
CREATE TABLE clinicians (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL UNIQUE REFERENCES auth_users(id) ON DELETE RESTRICT,
    full_name     TEXT NOT NULL,                      -- 🔒
    license_no    TEXT,                               -- 🔒 면허번호
    role_title    TEXT,                               -- 정신건강의학과 전문의/임상심리/상담사
    org_name      TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 임상가-환자 배정 (다대다, 담당범위 RBAC 근거)
CREATE TABLE clinician_patient (
    clinician_id  UUID NOT NULL REFERENCES clinicians(id) ON DELETE CASCADE,
    patient_id    UUID NOT NULL REFERENCES patients(id)  ON DELETE CASCADE,
    assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (clinician_id, patient_id)
);

-- 4) 후원자(가족·동료 스폰서)
CREATE TABLE supporters (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name     TEXT NOT NULL,                      -- 🔒
    phone         TEXT NOT NULL,                      -- 🔒 (알림 트리거 대상)
    relation      TEXT,                               -- 가족/지인/회복동료
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE patient_supporters (
    patient_id    UUID NOT NULL REFERENCES patients(id)   ON DELETE CASCADE,
    supporter_id  UUID NOT NULL REFERENCES supporters(id) ON DELETE CASCADE,
    consent_to_notify BOOLEAN NOT NULL DEFAULT FALSE,  -- 알림 동의
    priority      SMALLINT NOT NULL DEFAULT 1,
    PRIMARY KEY (patient_id, supporter_id)
);

-- 5) 자극 라이브러리(노출치료용 미디어)
CREATE TYPE media_type AS ENUM ('image','video','audio','scenario');
CREATE TABLE exposure_media (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title         TEXT NOT NULL,
    media_type    media_type NOT NULL,
    cdn_key       TEXT NOT NULL,                      -- CDN 객체키(서명URL로만 접근)
    intensity     SMALLINT CHECK (intensity BETWEEN 1 AND 5), -- 자극 강도(위계)
    category      TEXT,                               -- 슬롯/스포츠베팅/온라인 등
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6) 훈련 세션(ERP·파도타기 상위 컨테이너)
CREATE TYPE session_type AS ENUM ('erp_exposure','urge_surfing','education','self_check');
CREATE TABLE training_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    session_type    session_type NOT NULL,
    media_id        UUID REFERENCES exposure_media(id),  -- ERP일 때 자극 참조
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    duration_sec    INTEGER GENERATED ALWAYS AS
                      (EXTRACT(EPOCH FROM (ended_at - started_at))::INT) STORED,
    completed       BOOLEAN NOT NULL DEFAULT FALSE,
    client_event_id UUID NOT NULL,                    -- 멱등성 키(오프라인 생성)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (patient_id, client_event_id)              -- 멱등 보장
);

-- 7) 충동 파도타기 세션(성공/실패 결과)
CREATE TYPE surf_outcome AS ENUM ('success','relapse','aborted');
CREATE TABLE urge_surfing_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL UNIQUE REFERENCES training_sessions(id) ON DELETE CASCADE,
    patient_id      UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    peak_urge       SMALLINT CHECK (peak_urge BETWEEN 0 AND 10), -- 최고 갈망
    outcome         surf_outcome NOT NULL,            -- 성공(파도 넘김)/재발/중단
    coping_skill    TEXT,                             -- 사용 대처기술(호흡/주의분산 등)
    duration_sec    INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8) VAS 기록(훈련 전·후 갈망 0~10)
CREATE TYPE vas_phase AS ENUM ('pre','post');
CREATE TABLE vas_records (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
    patient_id      UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    phase           vas_phase NOT NULL,               -- pre/post
    vas_value       SMALLINT NOT NULL CHECK (vas_value BETWEEN 0 AND 10),
    recorded_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (session_id, phase)                        -- 세션당 전/후 1회
);

-- 9) 갈망 시계열(TimescaleDB hypertable)
CREATE TABLE craving_timeseries (
    patient_id    UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    session_id    UUID REFERENCES training_sessions(id) ON DELETE SET NULL,
    ts            TIMESTAMPTZ NOT NULL,
    craving_value REAL NOT NULL CHECK (craving_value BETWEEN 0 AND 10),
    source        TEXT NOT NULL DEFAULT 'in_session', -- in_session/ema(수시조사)
    PRIMARY KEY (patient_id, ts)
);
SELECT create_hypertable('craving_timeseries','ts', chunk_time_interval => INTERVAL '7 days');
-- 연속집계(대시보드 추이 가속)
CREATE MATERIALIZED VIEW craving_daily WITH (timescaledb.continuous) AS
  SELECT patient_id, time_bucket('1 day', ts) AS day,
         avg(craving_value) AS avg_craving, max(craving_value) AS peak_craving
  FROM craving_timeseries GROUP BY patient_id, day;

-- 10) 차단 이벤트(도박 앱/사이트 차단 시도·감지)
CREATE TYPE block_result AS ENUM ('blocked','bypassed','warned');
CREATE TABLE blocking_events (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id    UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    target        TEXT NOT NULL,                      -- 감지 도메인/앱 패키지(가명화)
    result        block_result NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL,
    device_id     TEXT,
    client_event_id UUID NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (patient_id, client_event_id)
);

-- 11) 교육 콘텐츠 & 진도
CREATE TABLE education_contents (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_code   TEXT UNIQUE NOT NULL,
    title         TEXT NOT NULL,
    order_no      SMALLINT NOT NULL,
    total_units   SMALLINT NOT NULL DEFAULT 1
);
CREATE TABLE education_progress (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id    UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    content_id    UUID NOT NULL REFERENCES education_contents(id) ON DELETE CASCADE,
    completed_units SMALLINT NOT NULL DEFAULT 0,
    progress_pct  SMALLINT NOT NULL DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
    completed_at  TIMESTAMPTZ,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (patient_id, content_id)
);

-- 12) 알림 로그(후원자·1336 트리거)
CREATE TYPE alert_channel AS ENUM ('fcm','apns','sms','call');
CREATE TYPE alert_status  AS ENUM ('queued','sent','delivered','failed');
CREATE TABLE alerts (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id    UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    trigger_type  TEXT NOT NULL,                      -- high_urge/relapse/sos/blocking_bypass
    channel       alert_channel NOT NULL,
    recipient     TEXT NOT NULL,                       -- supporter_id / '1336' / device_token(가명)
    payload       JSONB,
    status        alert_status NOT NULL DEFAULT 'queued',
    triggered_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivered_at  TIMESTAMPTZ
);

-- 13) 동의 관리(개인정보보호법·임상시험)
CREATE TABLE consents (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id    UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    consent_type  TEXT NOT NULL,                      -- sensitive_health/data_use/supporter_notify
    version       TEXT NOT NULL,                       -- 동의서 버전
    granted       BOOLEAN NOT NULL,
    granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at    TIMESTAMPTZ,
    UNIQUE (patient_id, consent_type, version)
);

-- 14) 감사 로그(규제용, append-only)
CREATE TABLE audit_log (
    id            BIGSERIAL PRIMARY KEY,
    actor_user_id UUID,                               -- 행위 주체
    actor_role    user_role,
    action        TEXT NOT NULL,                       -- READ/CREATE/UPDATE/DELETE/EXPORT/LOGIN
    entity        TEXT NOT NULL,                       -- 테이블/리소스명
    entity_id     TEXT,
    patient_id    UUID,                                -- 접근된 환자(데이터 주체)
    ip_address    INET,
    request_id    UUID,
    meta          JSONB,
    occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- append-only 강제(트리거로 UPDATE/DELETE 차단)
CREATE RULE audit_no_update AS ON UPDATE TO audit_log DO INSTEAD NOTHING;
CREATE RULE audit_no_delete AS ON DELETE TO audit_log DO INSTEAD NOTHING;
```

**핵심 인덱스**

| 테이블 | 인덱스 | 목적 |
|---|---|---|
| training_sessions | `(patient_id, started_at DESC)` | 환자별 최근 세션 조회 |
| training_sessions | `(patient_id, client_event_id)` UNIQUE | 동기화 멱등성 |
| vas_records | `(patient_id, recorded_at)` | VAS 추이 집계 |
| urge_surfing_sessions | `(patient_id, outcome, created_at)` | 성공률 집계 |
| craving_timeseries | hypertable `(patient_id, ts)` + 7d 청크 | 시계열 범위 스캔 |
| blocking_events | `(patient_id, detected_at DESC)` | 차단 타임라인 |
| alerts | `(patient_id, triggered_at DESC)`, `(status)` | 미발송 재시도 큐 |
| audit_log | `(patient_id, occurred_at)`, `(actor_user_id, occurred_at)` | 규제 추적 |

> **테이블 총 17개**: auth_users, patients, clinicians, clinician_patient, supporters, patient_supporters, exposure_media, training_sessions, urge_surfing_sessions, vas_records, craving_timeseries, blocking_events, education_contents, education_progress, alerts, consents, audit_log (+ 연속집계 뷰 craving_daily).

---

### 4.3 REST API 엔드포인트 설계

> 베이스: `/api/v1` · 인증: `Authorization: Bearer <JWT>` · 권한: 🟢환자 🔵임상가 🟣관리자

#### (A) 환자앱용 API

| 메서드 | 경로 | 설명 | 권한 |
|---|---|---|---|
| POST | `/auth/login` | 로그인(JWT 발급) | 전체 |
| POST | `/auth/refresh` | 액세스 토큰 갱신 | 전체 |
| GET | `/me` | 내 프로필·프로그램 단계 | 🟢 |
| GET | `/exposure-media?intensity=` | 자극 라이브러리(서명URL 포함) | 🟢🔵 |
| POST | `/training-sessions` | 훈련 세션 생성(멱등: client_event_id) | 🟢 |
| PATCH | `/training-sessions/{id}` | 세션 종료/완료 처리 | 🟢 |
| POST | `/training-sessions/{id}/vas` | VAS 전/후 기록(0~10) | 🟢 |
| POST | `/urge-surfing` | 파도타기 결과(성공/재발/중단) | 🟢 |
| POST | `/craving-timeseries:batch` | 갈망 시계열 배치 업로드 | 🟢 |
| POST | `/blocking-events` | 차단 시도/감지 보고(멱등) | 🟢 |
| GET/PATCH | `/education-progress` | 교육 진도 조회/갱신 | 🟢 |
| POST | `/sos` | 위기 SOS(후원자·1336 알림 트리거) | 🟢 |
| GET/PATCH | `/consents` | 동의 조회/철회 | 🟢 |
| POST | `/sync` | 오프라인 이벤트 묶음 동기화(멱등 일괄) | 🟢 |
| POST | `/devices` | FCM/APNs 토큰 등록 | 🟢 |

#### (B) 의사·상담사용 웹 대시보드 API (★)

| 메서드 | 경로 | 설명 | 권한 |
|---|---|---|---|
| GET | `/dashboard/patients` | 담당 환자 목록(상태·최근활동·위험요약) | 🔵🟣 |
| GET | `/dashboard/patients/{id}/overview` | 환자 종합(핵심지표 카드) | 🔵🟣 |
| GET | `/dashboard/patients/{id}/metrics/activity?from=&to=` | **활동 수행 횟수**(세션 유형별) | 🔵🟣 |
| GET | `/dashboard/patients/{id}/metrics/education` | **교육 진도율** | 🔵🟣 |
| GET | `/dashboard/patients/{id}/metrics/vas-trend?bucket=day` | **VAS 변화 추이**(pre/post·시계열) | 🔵🟣 |
| GET | `/dashboard/patients/{id}/metrics/urge-surfing` | **충동 파도타기 성공/실패율** | 🔵🟣 |
| GET | `/dashboard/patients/{id}/craving?from=&to=&bucket=` | 갈망 시계열(연속집계) | 🔵🟣 |
| GET | `/dashboard/patients/{id}/blocking` | 차단 이벤트 타임라인 | 🔵🟣 |
| GET | `/dashboard/alerts?status=&from=` | 알림(후원자·1336) 로그 | 🔵🟣 |
| GET | `/dashboard/cohort/metrics` | 코호트 집계(프로그램 단계별 평균) | 🔵🟣 |
| POST | `/admin/export` | 규제/임상 데이터 익명화 추출(감사 기록) | 🟣 |
| GET | `/admin/audit-log?patient_id=` | 감사 추적 조회 | 🟣 |

> **RBAC 규칙**: 임상가는 `clinician_patient` 배정된 환자만 조회 가능(쿼리셋 강제 필터). 모든 대시보드 GET은 `audit_log`에 `action=READ` 기록.

---

### 4.4 DTx 치료성과 지표 정의 & 산출 쿼리

| 지표 | 정의 | 단위 |
|---|---|---|
| **활동 수행 횟수** | 기간 내 완료(completed=true) 세션 수, 유형별 | 회 |
| **교육 진도율** | Σ(완료 진도)/Σ(전체) ×100 | % |
| **VAS 변화량(Δ)** | session별 `pre - post` 평균(양수=갈망 감소=개선) | 점 |
| **파도타기 성공률** | success / (success+relapse+aborted) ×100 | % |
| **갈망 추이** | 일자별 평균/최고 갈망(craving_daily) | 0~10 |

```sql
-- ① VAS 전·후 변화 추이 (일자별 갈망 감소량)
SELECT date_trunc('day', t.started_at) AS day,
       AVG(pre.vas_value)  AS avg_pre,
       AVG(post.vas_value) AS avg_post,
       AVG(pre.vas_value - post.vas_value) AS avg_reduction  -- ↑ 클수록 개선
FROM training_sessions t
JOIN vas_records pre  ON pre.session_id  = t.id AND pre.phase='pre'
JOIN vas_records post ON post.session_id = t.id AND post.phase='post'
WHERE t.patient_id = :patient_id AND t.started_at BETWEEN :from AND :to
GROUP BY 1 ORDER BY 1;

-- ② 충동 파도타기 성공률
SELECT COUNT(*) FILTER (WHERE outcome='success') AS success,
       COUNT(*) AS total,
       ROUND(100.0 * COUNT(*) FILTER (WHERE outcome='success') / NULLIF(COUNT(*),0), 1)
         AS success_rate_pct
FROM urge_surfing_sessions
WHERE patient_id = :patient_id AND created_at BETWEEN :from AND :to;

-- ③ 교육 진도율
SELECT ROUND(AVG(progress_pct),1) AS education_completion_pct
FROM education_progress WHERE patient_id = :patient_id;

-- ④ 활동 수행 횟수(유형별)
SELECT session_type, COUNT(*) AS done
FROM training_sessions
WHERE patient_id=:patient_id AND completed AND started_at BETWEEN :from AND :to
GROUP BY session_type;
```

---

### 4.5 데이터 거버넌스 (식약처·임상시험 대비)

| 영역 | 정책 |
|---|---|
| **암호화** | 전송 TLS 1.2+, 저장 AES-256(at rest). 민감 컬럼(이름·연락처·면허·이메일)은 앱계층 봉투암호화(KMS DEK). 키 회전 정책은 System Architect와 합의 |
| **익명화/가명화** | 분석·추출 시 `pseudonym_code` 사용, 식별정보 분리 저장. `/admin/export`는 직접식별자 제거 후 반출 |
| **보존기간** | 임상 데이터 의료기기 규정에 따라 장기 보존(예: 시판 후 추적기간), 동의철회 시 분석셋과 식별정보 분리·식별정보 파기. 정책값은 Clinical&Safety 확정 후 보존 잡(job)에 반영 |
| **동의관리** | `consents` 버전관리, 철회(`revoked_at`) 시 후속 수집 중단·알림 비활성. 동의 없는 민감정보 수집 차단 |
| **감사추적** | `audit_log` append-only(RULE로 UPDATE/DELETE 무효화). 모든 READ/EXPORT/로그인/권한변경 기록, request_id로 추적 |
| **최소수집** | 생년월일 대신 출생연도, 차단 대상 도메인 가명화 |

### 4.6 동기화·멱등성·무결성

- **오프라인→서버**: 클라이언트가 이벤트에 `client_event_id`(UUID) 부여 → `/sync`로 배치 전송. 서버는 `UNIQUE(patient_id, client_event_id)`로 **중복 무시(upsert-ignore)**, 부분 성공 결과를 항목별 반환.
- **멱등성**: 모든 쓰기 엔드포인트는 멱등키 수용. 재전송/재시도 시 동일 결과 보장(at-least-once 전송 + exactly-once 효과).
- **무결성**: FK 제약·CHECK(VAS 0~10, 성공률 enum)·세션당 pre/post 1회 UNIQUE·트랜잭션 경계로 세션-VAS-결과 원자적 커밋. 서버 권위 타임스탬프 별도 보관(클라이언트 시계 신뢰 금지).

---

## 5. 핸드오프 체크리스트

- [ ] **System Architect**: KMS 키 관리·TimescaleDB 운영사양·백업 RPO/RTO·보존기간 정책값 확정 수령
- [ ] **Clinical & Safety**: VAS 척도·파도타기 성공 정의·위기 알림 임계치·동의서 항목/버전 검증 완료
- [ ] **Frontend/UX**: 대시보드 API OpenAPI 계약 합의, 집계 단위(bucket)·페이지네이션 규약 확정
- [ ] **Native Integration**: `/sync` 페이로드 스키마·멱등키 규약·서명URL·푸시 토큰 등록 연동 완료
- [ ] DDL 마이그레이션 + hypertable/연속집계 생성 스크립트 리뷰 통과
- [ ] RBAC 쿼리셋 필터(임상가=배정환자만) 및 audit_log 자동기록 미들웨어 검증
- [ ] 멱등성·동의철회·익명화 추출 시나리오 통합 테스트 통과
- [ ] OpenAPI 스펙 `/api/v1` 게시 및 Orchestrator 승인

---
> 본 문서는 SSOT. 스키마/계약 변경 시 버전 증가 + 마이그레이션 노트 + 본 체크리스트 재검토 필수.
