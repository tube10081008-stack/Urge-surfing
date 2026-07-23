"""DRF 시리얼라이저 + API 계약에 맞춘 검증 로직."""
from rest_framework import serializers

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


class LearningConceptSerializer(serializers.ModelSerializer):
    """GET(목록) / PATCH(메모 저장) /learning-concepts."""

    class Meta:
        model = LearningConcept
        fields = [
            "id",
            "key",
            "group_no",
            "group_title",
            "title",
            "title_en",
            "originator",
            "summary",
            "connection",
            "note",
        ]
        # 큐레이션 내용은 읽기 전용, 사용자 메모(note)만 수정 가능
        read_only_fields = [
            "id", "key", "group_no", "group_title", "title",
            "title_en", "originator", "summary", "connection",
        ]


class CopingActionSerializer(serializers.ModelSerializer):
    """GET/POST /coping-actions 요청/응답."""

    class Meta:
        model = CopingAction
        fields = [
            "id",
            "title",
            "category",
            "direction",
            "note",
            "effort",
            "is_custom",
        ]
        read_only_fields = ["id", "is_custom"]


class StateCheckinSerializer(serializers.ModelSerializer):
    """POST/PATCH/GET /state-checkins 요청/응답."""

    class Meta:
        model = StateCheckin
        fields = [
            "id",
            "arousal",
            "body_part",
            "sensation",
            "trigger",
            "action",
            "arousal_after",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate_arousal(self, value):
        if not (1 <= value <= 5):
            raise serializers.ValidationError("arousal은 1~5 사이여야 합니다.")
        return value

    def validate_arousal_after(self, value):
        if value is not None and not (1 <= value <= 5):
            raise serializers.ValidationError("arousal_after는 1~5 사이여야 합니다.")
        return value


class LifeCompassSerializer(serializers.ModelSerializer):
    """GET/PUT /compass 요청/응답."""

    class Meta:
        model = LifeCompass
        fields = [
            "life_goal",
            "study_domain",
            "goal_1y",
            "goal_5y",
            "goal_10y",
            "updated_at",
        ]
        read_only_fields = ["updated_at"]


class ExposureMediaSerializer(serializers.ModelSerializer):
    """GET /exposure-media 응답."""

    class Meta:
        model = ExposureMedia
        fields = [
            "id",
            "title",
            "media_type",
            "category",
            "intensity",
            "asset_ref",
            "media_url",
            "content_warning",
        ]


class TrainingSessionCreateSerializer(serializers.ModelSerializer):
    """POST /training-sessions 요청/응답.

    요청: {session_type, media_id?}
    응답: {id, session_type, media_id, started_at, completed}

    media_id는 관대하게 처리한다: 존재하지 않는 id가 와도 400 대신
    media 없이 세션을 생성한다(앱이 폴백 더미 id를 보내는 경우 대비).
    """

    # 입력 전용. 존재 검증을 강제하지 않으려고 IntegerField 사용.
    media_id = serializers.IntegerField(required=False, allow_null=True)

    class Meta:
        model = TrainingSession
        fields = ["id", "session_type", "media_id", "started_at", "completed"]
        read_only_fields = ["id", "started_at", "completed"]

    def create(self, validated_data):
        media_pk = validated_data.pop("media_id", None)
        media = (
            ExposureMedia.objects.filter(pk=media_pk).first() if media_pk else None
        )
        return TrainingSession.objects.create(media=media, **validated_data)

    def to_representation(self, instance):
        return {
            "id": instance.id,
            "session_type": instance.session_type,
            "media_id": instance.media_id,
            "started_at": (
                instance.started_at.isoformat() if instance.started_at else None
            ),
            "completed": instance.completed,
        }


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
