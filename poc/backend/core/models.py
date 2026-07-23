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


class LifeCompass(models.Model):
    """삶의 나침반 — 의미 있는 목표와 기간별 계획(단일 데모 사용자, 싱글턴).

    도박 충동의 기저(무료함·외로움·연결 열망)를 '방향과 몰입'으로 대체하기
    위한 상담 과제를 담는다. 충동/결과 화면에서 '왜 견디는가'로 상기시킨다.
    """

    life_goal = models.TextField("의미 있는 삶의 목표", blank=True, default="")
    study_domain = models.TextField("1만 시간 학습 영역", blank=True, default="")
    goal_1y = models.TextField("1년 목표", blank=True, default="")
    goal_5y = models.TextField("5년 목표", blank=True, default="")
    goal_10y = models.TextField("10년 목표", blank=True, default="")
    updated_at = models.DateTimeField("수정 시각", auto_now=True)

    class Meta:
        verbose_name = "삶의 나침반"
        verbose_name_plural = "삶의 나침반"

    def __str__(self):
        return f"삶의 나침반 #{self.pk}"


class StateCheckin(models.Model):
    """신경계 상태 체크인 — 수용의 창(WoT) 위 내 위치 기록.

    상담 과제: 충동은 신호 → '몸 어디서, 어떤 감각으로, 왜'를 알아차리고
    행동(산책·운동·공부 등)으로 상태값을 옮긴 뒤 다시 체크해 전후를 비교한다.
    """

    class Arousal(models.IntegerChoices):
        SHUTDOWN = 1, "무기력/멍함"
        LOW = 2, "가라앉음/무료함"
        WINDOW = 3, "안정(창 안)"
        HIGH = 4, "긴장/들뜸"
        OVER = 5, "과각성/충동"

    arousal = models.PositiveSmallIntegerField(
        "각성도(1~5)", choices=Arousal.choices
    )
    body_part = models.CharField("몸 부위", max_length=50, blank=True, default="")
    sensation = models.CharField("감각", max_length=50, blank=True, default="")
    trigger = models.CharField(
        "신호의 이유/맥락", max_length=300, blank=True, default=""
    )
    action = models.CharField("상태 이동 행동", max_length=100, blank=True, default="")
    # 행동 후 재체크 값(없으면 아직 미완료)
    arousal_after = models.PositiveSmallIntegerField(
        "행동 후 각성도", choices=Arousal.choices, null=True, blank=True
    )
    created_at = models.DateTimeField("기록 시각", auto_now_add=True)
    updated_at = models.DateTimeField("수정 시각", auto_now=True)

    class Meta:
        verbose_name = "상태 체크인"
        verbose_name_plural = "상태 체크인"
        ordering = ["-created_at"]

    def __str__(self):
        return f"체크인 #{self.pk} ({self.get_arousal_display()})"


class CopingAction(models.Model):
    """상태를 옮기는 행동 카탈로그(가이드 표).

    각 행동을 '방향'으로 태그해 지금 상태(수용의 창 위 위치)에 맞는 행동을
    추천한다. 사용자가 자신의 행동을 추가(is_custom=True)할 수도 있다.
    """

    class Direction(models.TextChoices):
        UP = "up", "끌어올리기(무기력→활력)"
        DOWN = "down", "가라앉히기(과각성→안정)"
        GROUND = "ground", "중심잡기(창 안 안정)"

    title = models.CharField("행동", max_length=100, unique=True)
    category = models.CharField("분류", max_length=50)
    direction = models.CharField(
        "방향", max_length=10, choices=Direction.choices
    )
    note = models.CharField("효과/경험", max_length=300, blank=True, default="")
    # 접근성: 1=즉시 가능, 2=보통, 3=시간·준비 필요
    effort = models.PositiveSmallIntegerField("실행 난이도(1~3)", default=1)
    is_custom = models.BooleanField("사용자 추가", default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "대처 행동"
        verbose_name_plural = "대처 행동"
        ordering = ["category", "id"]

    def __str__(self):
        return f"{self.title} ({self.direction})"


class LearningConcept(models.Model):
    """회복 학습 노트 — 학술 개념 카드 + 사용자 메모.

    큐레이션된 개념(요약·원조 학자·회복과의 연결)은 시드로 관리하고,
    note 필드에 사용자가 상담에서 배운 것을 적어 공부한다(재시드 시 note 보존).
    """

    key = models.CharField("식별키", max_length=50, unique=True)
    group_no = models.PositiveSmallIntegerField("그룹 번호", default=1)
    group_title = models.CharField("그룹명", max_length=50, blank=True, default="")
    title = models.CharField("개념명", max_length=100)
    title_en = models.CharField("영문명", max_length=120, blank=True, default="")
    originator = models.CharField("제안 학자", max_length=120, blank=True, default="")
    summary = models.TextField("요약", blank=True, default="")
    connection = models.TextField("내 회복과의 연결", blank=True, default="")
    # 사용자 메모(공부 필기) — 재시드 시 보존
    note = models.TextField("내 메모", blank=True, default="")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "학습 개념"
        verbose_name_plural = "학습 개념"
        ordering = ["group_no", "id"]

    def __str__(self):
        return f"[{self.group_no}] {self.title}"
