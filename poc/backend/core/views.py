"""
API 뷰. API 계약(Base: /api/v1)에 맞춰 구현.

- ExposureMedia: 목록(GET)
- TrainingSession: 생성(POST), 완료 처리(PATCH), VAS 기록(POST 커스텀 액션)
- UrgeSurfing: 생성(POST)
- Dashboard: VAS 추세 집계(GET)
"""
from django.db.models import Avg
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    ExposureMedia,
    TrainingSession,
    VasRecord,
)
from .serializers import (
    ExposureMediaSerializer,
    TrainingSessionCompleteSerializer,
    TrainingSessionCreateSerializer,
    UrgeSurfingSerializer,
    VasRecordSerializer,
)


class ExposureMediaViewSet(
    mixins.ListModelMixin,
    viewsets.GenericViewSet,
):
    """GET /exposure-media → 노출 자극 목록."""

    queryset = ExposureMedia.objects.all().order_by("id")
    serializer_class = ExposureMediaSerializer
    pagination_class = None  # PoC: 페이지네이션 없이 전체 반환


class TrainingSessionViewSet(
    mixins.CreateModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    """훈련 세션 생성 / 완료(PATCH) / VAS 기록."""

    queryset = TrainingSession.objects.all()

    def get_serializer_class(self):
        if self.action in ("update", "partial_update"):
            return TrainingSessionCompleteSerializer
        return TrainingSessionCreateSerializer

    def partial_update(self, request, *args, **kwargs):
        """PATCH /training-sessions/{id} {completed:true}.

        완료 처리 시 ended_at을 현재 시각으로, duration_sec을
        started_at~ended_at 차이로 계산해 저장한다.
        """
        instance = self.get_object()
        completed = request.data.get("completed", False)

        if completed and not instance.completed:
            now = timezone.now()
            instance.completed = True
            instance.ended_at = now
            instance.duration_sec = int((now - instance.started_at).total_seconds())
            instance.save(update_fields=["completed", "ended_at", "duration_sec"])

        serializer = TrainingSessionCompleteSerializer(instance)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="vas")
    def vas(self, request, pk=None):
        """POST /training-sessions/{id}/vas {phase, vas_value}.

        세션당 phase(pre/post) 각 1회만 허용(UniqueConstraint).
        """
        session = self.get_object()
        serializer = VasRecordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # 동일 (session, phase) 중복 방지
        phase = serializer.validated_data["phase"]
        if VasRecord.objects.filter(session=session, phase=phase).exists():
            return Response(
                {"detail": f"해당 세션의 '{phase}' VAS는 이미 기록되었습니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        record = serializer.save(session=session)
        return Response(
            VasRecordSerializer(record).data,
            status=status.HTTP_201_CREATED,
        )


class UrgeSurfingViewSet(
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    """POST /urge-surfing → 충동 파도타기 결과 기록."""

    queryset = TrainingSession.objects.none()  # 라우터용 더미
    serializer_class = UrgeSurfingSerializer


class VasTrendView(APIView):
    """GET /dashboard/vas-trend.

    단일 데모 사용자 기준. 일자별(pre/post) VAS 평균과 감소량을
    Django ORM 집계(values + annotate)로 계산해 반환한다.

    감소량(avg_reduction) = avg_pre - avg_post
    """

    def get(self, request):
        # phase별 일자별 평균을 각각 집계 후 파이썬에서 일자 기준 병합
        base = VasRecord.objects.annotate(day=TruncDate("recorded_at"))

        pre_qs = (
            base.filter(phase=VasRecord.Phase.PRE)
            .values("day")
            .annotate(avg_pre=Avg("vas_value"))
        )
        post_qs = (
            base.filter(phase=VasRecord.Phase.POST)
            .values("day")
            .annotate(avg_post=Avg("vas_value"))
        )

        pre_map = {row["day"]: row["avg_pre"] for row in pre_qs}
        post_map = {row["day"]: row["avg_post"] for row in post_qs}

        days = sorted(set(pre_map) | set(post_map))
        result = []
        for day in days:
            avg_pre = pre_map.get(day)
            avg_post = post_map.get(day)
            avg_reduction = None
            if avg_pre is not None and avg_post is not None:
                avg_reduction = round(avg_pre - avg_post, 2)
            result.append(
                {
                    "day": day.isoformat(),
                    "avg_pre": round(avg_pre, 2) if avg_pre is not None else None,
                    "avg_post": round(avg_post, 2) if avg_post is not None else None,
                    "avg_reduction": avg_reduction,
                }
            )

        return Response(result, status=status.HTTP_200_OK)
