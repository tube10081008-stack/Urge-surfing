"""Django 어드민 등록 (PoC 데이터 확인용)."""
from django.contrib import admin

from .models import (
    CopingAction,
    ExposureMedia,
    LearningConcept,
    LifeCompass,
    StateCheckin,
    TrainingSession,
    UrgeSurfingSession,
    VasRecord,
)


@admin.register(LearningConcept)
class LearningConceptAdmin(admin.ModelAdmin):
    list_display = ("group_no", "title", "title_en", "originator")
    list_filter = ("group_no",)
    search_fields = ("title", "title_en", "summary", "note")


@admin.register(CopingAction)
class CopingActionAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "category", "direction", "effort", "is_custom")
    list_filter = ("direction", "category", "is_custom")
    search_fields = ("title", "note")


@admin.register(LifeCompass)
class LifeCompassAdmin(admin.ModelAdmin):
    list_display = ("id", "life_goal", "updated_at")


@admin.register(StateCheckin)
class StateCheckinAdmin(admin.ModelAdmin):
    list_display = (
        "id", "arousal", "body_part", "sensation", "action",
        "arousal_after", "created_at",
    )
    list_filter = ("arousal", "arousal_after")


@admin.register(ExposureMedia)
class ExposureMediaAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "media_type", "category", "intensity", "has_url")
    list_filter = ("media_type", "category")
    search_fields = ("title", "category", "media_url")
    fields = (
        "title",
        "media_type",
        "category",
        "intensity",
        "media_url",
        "content_warning",
        "asset_ref",
    )

    @admin.display(boolean=True, description="URL 등록됨")
    def has_url(self, obj):
        return bool(obj.media_url)


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
