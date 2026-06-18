"""core 앱 설정."""
from django.apps import AppConfig


class CoreConfig(AppConfig):
    default_auto_field = "django.db.models.AutoField"
    name = "core"
    verbose_name = "도박중독 DTx 코어"
