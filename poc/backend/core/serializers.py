"""DRF 시리얼라이저 + API 계약에 맞춘 검증 로직."""
from rest_framework import serializers

from .models import (
    ExposureMedia,
    TrainingSession,
    UrgeSurfingSession,
    VasRecord,
)


class ExposureMediaSerializer(serializers.ModelSerializer):
    """GET /exposure-media 응답."""

    class Meta:
        model = ExposureMedia
        fields = ["id", "title", "media_type", "category", "intensity", "asset_ref"]


class TrainingSessionCreateSerializer(serializers.ModelSerializer):
    """POST /training-sessions 요청/응답.

    요청: {session_type, media_id?}
    응답: {id, session_type, media_id, started_at, completed}
    """

    # 입력은 media_id, 모델 필드는 media 이므로 source 매핑
    media_id = serializers.PrimaryKeyRelatedField(
        source="media",
        queryset=ExposureMedia.objects.all(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = TrainingSession
        fields = ["id", "session_type", "media_id", "started_at", "completed"]
        read_only_fields = ["id", "started_at", "completed"]


class TrainingSessionCompleteSerializer(serializers.ModelSerializer):
    """PATCH /training-sessions/{id} 요청/응답.

    요청: {completed: true}
    응답: {id, completed, ended_at, duration_sec}
    """

    class Meta:
        model = TrainingSession
        fields = ["id", "completed", "ended_at", "duration_sec"]
        read_only_fields = ["id", "ended_at", "duration_sec"]


class VasRecordSerializer(serializers.ModelSerializer):
    """POST /training-sessions/{id}/vas 응답."""

    class Meta:
        model = VasRecord
        fields = ["id", "phase", "vas_value", "recorded_at"]
        read_only_fields = ["id", "recorded_at"]

    def validate_vas_value(self, value):
        """VAS 값 0~10 검증."""
        if not (0 <= value <= 10):
            raise serializers.ValidationError("vas_value는 0~10 사이여야 합니다.")
        return value


class UrgeSurfingSerializer(serializers.ModelSerializer):
    """POST /urge-surfing 요청/응답."""

    session_id = serializers.PrimaryKeyRelatedField(
        source="session",
        queryset=TrainingSession.objects.all(),
    )

    class Meta:
        model = UrgeSurfingSession
        fields = [
            "id",
            "session_id",
            "peak_urge",
            "outcome",
            "coping_skill",
            "duration_sec",
        ]
        read_only_fields = ["id"]

    def validate_peak_urge(self, value):
        """peak_urge 0~10 검증."""
        if not (0 <= value <= 10):
            raise serializers.ValidationError("peak_urge는 0~10 사이여야 합니다.")
        return value

    def validate_session_id(self, session):
        """세션당 충동 파도타기 결과는 1회만(OneToOne).

        주의: source="session"이지만 DRF의 필드별 검증 메서드는
        시리얼라이저 필드명(session_id) 기준으로 매핑된다.
        """
        if UrgeSurfingSession.objects.filter(session=session).exists():
            raise serializers.ValidationError(
                "해당 세션에는 이미 충동 파도타기 결과가 존재합니다."
            )
        return session
