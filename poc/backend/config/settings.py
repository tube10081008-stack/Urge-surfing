"""
도박중독 DTx 앱 P0 PoC 백엔드 설정.
- 인증 없음(단일 데모 사용자), SQLite, 정수 PK
- CORS 전체 허용, TIME_ZONE Asia/Seoul, USE_TZ True
"""
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# PoC 전용 - 실제 운영에서는 절대 사용 금지
SECRET_KEY = "django-insecure-poc-dtx-gambling-demo-key-do-not-use-in-prod"
DEBUG = True
ALLOWED_HOSTS = ["*"]

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

# SQLite 데이터베이스
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

STATIC_URL = "static/"

# CORS 전체 허용 (PoC 전용)
CORS_ALLOW_ALL_ORIGINS = True

# DRF 설정 - 인증 없음
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.AllowAny",
    ],
}
