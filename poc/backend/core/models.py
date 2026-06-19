"""
도박중독 DTx PoC 데이터 모델.

단일 데모 사용자 가정으로 사용자 FK는 두지 않는다.
- ExposureMedia: 노출 자극(ERP) 미디어 라이브러리
- TrainingSession: 훈련 세션(ERP 노출 / 충동 파도타기)
- VasRecord: VAS(주관적 고통/갈망 척도) 사전/사후 기록
- UrgeSurfingSession: 충동 파도타기 결과
"""
from django.db import models


class ExposureMedia(models.Model):
    """노출 자극 미디어 라이브러리 항목."""

    class MediaType(models.TextChoices):
        AUDIO = "audio", "오디오"
        VIDEO = "video", "비디오"
        IMAGE = "image", "이미지"

    title = models.CharField("제목", max_length=200)
    media_type = models.CharField(
        "미디어 유형", max_length=10, choices=MediaType.choices
    )
    category = models.CharField("카테고리", max_length=100)
    # 강도 1~5
    intensity = models.PositiveSmallIntegerField("강도(1~5)")
    # 실제 에셋 참조(레거시: 파일 경로/식별자)
    asset_ref = models.CharField("에셋 참조", max_length=500, blank=True, default="")
    # 실제 재생용 스트리밍 URL(영상/오디오/이미지). 비어 있으면 앱은 플레이스홀더로 대체.
    media_url = models.URLField("미디어 URL", max_length=1000, blank=True, default="")
    # 노출 전 표시할 맞춤 주의 문구(비우면 기본 문구 사용)
    content_warning = models.CharField(
        "주의 문구", max_length=300, blank=True, default=""
    )

    class Meta:
        verbose_name = "노출 자극 미디어"
        verbose_name_plural = "노출 자극 미디어"

    def __str__(self):
        return f"[{self.media_type}] {self.title}"


class TrainingSession(models.Model):
    """훈련 세션."""

    class SessionType(models.TextChoices):
        ERP_EXPOSURE = "erp_exposure", "ERP 노출"
        URGE_SURFING = "urge_surfing", "충동 파도타기"

    session_type = models.CharField(
        "세션 유형", max_length=20, choices=SessionType.choices
    )
    # ERP 노출 시 사용 미디어(충동 파도타기는 nullable)
    media = models.ForeignKey(
        ExposureMedia,
        verbose_name="미디어",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="sessions",
    )
    started_at = models.DateTimeField("시작 시각", auto_now_add=True)
    ended_at = models.DateTimeField("종료 시각", null=True, blank=True)
    completed = models.BooleanField("완료 여부", default=False)
    duration_sec = models.PositiveIntegerField("소요 시간(초)", null=True, blank=True)

    class Meta:
        verbose_name = "훈련 세션"
        verbose_name_plural = "훈련 세션"
        ordering = ["-started_at"]

    def __str__(self):
        return f"세션 #{self.pk} ({self.session_type})"


class VasRecord(models.Model):
    """VAS 사전/사후 기록. 세션당 phase별 1회만 허용."""

    class Phase(models.TextChoices):
        PRE = "pre", "사전"
        POST = "post", "사후"

    session = models.ForeignKey(
        TrainingSession,
        verbose_name="세션",
        on_delete=models.CASCADE,
        related_name="vas_records",
    )
    phase = models.CharField("단계", max_length=4, choices=Phase.choices)
    # 0~10
    vas_value = models.PositiveSmallIntegerField("VAS 값(0~10)")
    recorded_at = models.DateTimeField("기록 시각", auto_now_add=True)

    class Meta:
        verbose_name = "VAS 기록"
        verbose_name_plural = "VAS 기록"
        constraints = [
            # 세션당 pre/post 각 1회만 허용
            models.UniqueConstraint(
                fields=["session", "phase"],
                name="uniq_session_phase",
            )
        ]

    def __str__(self):
        return f"세션 #{self.session_id} {self.phase}={self.vas_value}"


class UrgeSurfingSession(models.Model):
    """충동 파도타기 결과(세션과 1:1)."""

    class Outcome(models.TextChoices):
        SUCCESS = "success", "성공"
        RELAPSE = "relapse", "재발"
        ABORTED = "aborted", "중단"

    session = models.OneToOneField(
        TrainingSession,
        verbose_name="세션",
        on_delete=models.CASCADE,
        related_name="urge_surfing",
    )
    # 0~10
    peak_urge = models.PositiveSmallIntegerField("최고 충동(0~10)")
    outcome = models.CharField("결과", max_length=10, choices=Outcome.choices)
    coping_skill = models.CharField("사용한 대처 기술", max_length=200)
    duration_sec = models.PositiveIntegerField("소요 시간(초)")

    class Meta:
        verbose_name = "충동 파도타기 세션"
        verbose_name_plural = "충동 파도타기 세션"

    def __str__(self):
        return f"파도타기 세션 #{self.session_id} ({self.outcome})"
