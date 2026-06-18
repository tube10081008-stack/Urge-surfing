"""
도박중독 DTx 앱 백엔드 설정.

기본값은 P0 PoC(로컬 개발)에 맞춰져 있고, **환경변수를 주입하면 운영 모드로 승격**된다.
- 환경변수 없음 → PoC: SQLite, DEBUG=True, CORS 전체 허용 (로컬/SessionStart 훅 그대로 동작)
- 환경변수 주입 → 운영: PostgreSQL, DEBUG=False, CORS 제한, 보안 헤더, WhiteNoise 정적파일

운영 배포는 poc/DEPLOY.md 참조.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


def env_bool(key: str, default: bool) -> bool:
    """환경변수를 불리언으로 해석."""
    return os.environ.get(key, str(default)).lower() in ("1", "true", "yes", "on")


def env_list(key: str) -> list[str]:
    """콤마 구분 환경변수를 리스트로 (빈 값은 제외)."""
    return [v.strip() for v in os.environ.get(key, "").split(",") if v.strip()]


# ── 핵심 보안 설정 ──────────────────────────────────────────────
# 운영에서는 DJANGO_SECRET_KEY를 반드시 주입할 것. (미주입 시 PoC 임시 키)
SECRET_KEY = os.environ.get(
    "DJANGO_SECRET_KEY",
    "django-insecure-poc-dtx-gambling-demo-key-do-not-use-in-prod",
)
DEBUG = env_bool("DJANGO_DEBUG", True)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS") or ["*"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # 서드파티
    "rest_framework",
    "corsheaders",
    # 로컬 앱
    "core",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",  # CORS는 최상단에 위치
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# WhiteNoise(운영 정적파일 서빙) — 패키지가 설치돼 있을 때만 활성화.
# 로컬 PoC(requirements.txt)에는 미포함이므로 import 실패 시 조용히 건너뜀.
try:
    import whitenoise  # noqa: F401

    MIDDLEWARE.insert(2, "whitenoise.middleware.WhiteNoiseMiddleware")
    _WHITENOISE = True
except ImportError:
    _WHITENOISE = False

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# ── 데이터베이스 ────────────────────────────────────────────────
# DATABASE_URL 환경변수가 있으면 PostgreSQL 등 운영 DB, 없으면 PoC SQLite.
if os.environ.get("DATABASE_URL"):
    import dj_database_url

    DATABASES = {
        "default": dj_database_url.config(
            conn_max_age=600,
            ssl_require=env_bool("DJANGO_DB_SSL_REQUIRE", False),
        )
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }

# 정수 PK 기본값
DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

AUTH_PASSWORD_VALIDATORS = []

LANGUAGE_CODE = "ko-kr"
TIME_ZONE = "Asia/Seoul"
USE_I18N = True
USE_TZ = True

# ── 정적 파일 ──────────────────────────────────────────────────
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
if _WHITENOISE and not DEBUG:
    STORAGES = {
        "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
        "staticfiles": {
            "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"
        },
    }

# ── CORS ───────────────────────────────────────────────────────
# CORS_ALLOWED_ORIGINS 환경변수가 있으면 화이트리스트, 없으면 PoC 전체 허용.
_cors_origins = env_list("CORS_ALLOWED_ORIGINS")
if _cors_origins:
    CORS_ALLOWED_ORIGINS = _cors_origins
    CORS_ALLOW_ALL_ORIGINS = False
else:
    CORS_ALLOW_ALL_ORIGINS = True

# ── DRF 설정 (PoC: 인증 없음) ───────────────────────────────────
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.AllowAny",
    ],
}

# ── 운영 보안 헤더 (DEBUG=False일 때만) ─────────────────────────
if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", True)
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = int(os.environ.get("DJANGO_HSTS_SECONDS", "2592000"))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")
