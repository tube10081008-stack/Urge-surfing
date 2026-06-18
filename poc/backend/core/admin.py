"""Django 어드민 등록 (PoC 데이터 확인용)."""
from django.contrib import admin

from .models import (
    ExposureMedia,
    TrainingSession,
    UrgeSurfingSession,
    VasRecord,
)


@admin.register(ExposureMedia)
class ExposureMediaAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "media_type", "category", "intensity")
    list_filter = ("media_type", "category")


@admin.register(TrainingSession)
class TrainingSessionAdmin(admin.ModelAdmin):
    list_display = ("id", "session_type", "media", "started_at", "completed", "duration_sec")
    list_filter = ("session_type", "completed")


@admin.register(VasRecord)
class VasRecordAdmin(admin.ModelAdmin):
    list_display = ("id", "session", "phase", "vas_value", "recorded_at")
    list_filter = ("phase",)


@admin.register(UrgeSurfingSession)
class UrgeSurfingSessionAdmin(admin.ModelAdmin):
    list_display = ("id", "session", "peak_urge", "outcome", "coping_skill", "duration_sec")
    list_filter = ("outcome",)
