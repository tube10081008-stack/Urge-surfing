"""
시드 데이터 적재 커맨드.

사용법: python manage.py seed

노출 자극 미디어를 적재한다. 멱등성을 위해 title 기준으로 get_or_create 사용.
media_url 은 저작권 프리 자체 생성 클립(poc/media/exposure/)을 jsDelivr CDN으로 서빙.
실제 도박 자극 URL로 Django 관리자(/admin)에서 교체해 사용한다.
"""
from django.core.management.base import BaseCommand

from core.coping_catalog import COPING_CATALOG
from core.learning_catalog import LEARNING_CATALOG
from core.models import CopingAction, ExposureMedia, LearningConcept


# 자체 생성 클립을 커밋 SHA 고정 jsDelivr URL로 서빙(브랜치명에 슬래시가 있어 SHA 사용).
_CDN = (
    "https://cdn.jsdelivr.net/gh/tube10081008-stack/Urge-surfing@"
    "e6f86ab3ce1d575b2a8e204ae8431cfee41341f1/poc/media/exposure"
)

# 상담사 음성 가이드(파도타기 중 재생). category='음성가이드'는 앱에서
# 노출 자극 목록에서 제외되고, 대처법 "상담 음성 가이드"로 표시된다.
_CDN_GUIDE = (
    "https://cdn.jsdelivr.net/gh/tube10081008-stack/Urge-surfing@"
    "c6c301ac3ef462916515261b1e35a1c59c2db100/poc/media/guide"
)

# seed 가 기존 행의 media_url 을 덮어써도 되는 "데모 호스트"(관리자 실제 URL은 보존).
_DEMO_HOSTS = (
    "cdn.jsdelivr.net",
    "flutter.github.io",
    "soundhelix.com",
    "picsum.photos",
)

SEED_MEDIA = [
    {
        "title": "온라인 슬롯머신 릴 영상",
        "media_type": ExposureMedia.MediaType.IMAGE,
        "category": "슬롯",
        "intensity": 5,
        "asset_ref": "slot_jackpot.gif",
        "media_url": f"{_CDN}/slot_jackpot.gif",
    },
    {
        "title": "스포츠 베팅 배당률 화면",
        "media_type": ExposureMedia.MediaType.IMAGE,
        "category": "스포츠베팅",
        "intensity": 3,
        "asset_ref": "odds_board.png",
        "media_url": f"{_CDN}/odds_board.png",
    },
    {
        # 기존 행 제자리 갱신(제목 유지) — 약한 강도 슬롯 스핀으로 대체
        "title": "경마 경주 실황 영상",
        "media_type": ExposureMedia.MediaType.IMAGE,
        "category": "슬롯",
        "intensity": 2,
        "asset_ref": "slot_soft.gif",
        "media_url": f"{_CDN}/slot_soft.gif",
    },
    {
        "title": "카지노 칩 사운드",
        "media_type": ExposureMedia.MediaType.AUDIO,
        "category": "카지노",
        "intensity": 2,
        "asset_ref": "win_jingle.wav",
        "media_url": f"{_CDN}/win_jingle.wav",
    },
    {
        # 노출 자극이 아닌 파도타기 대처용 음성 가이드(1회기, 7.4분)
        "title": "상담사 음성 가이드 · 1회기",
        "media_type": ExposureMedia.MediaType.AUDIO,
        "category": "음성가이드",
        "intensity": 1,
        "asset_ref": "counselor_guide_01.mp3",
        "media_url": f"{_CDN_GUIDE}/counselor_guide_01.mp3",
    },
    {
        # 2회기: 무료함·외로움, 관계 단절/연결 열망, 삶의 목표
        "title": "상담사 음성 가이드 · 2회기",
        "media_type": ExposureMedia.MediaType.AUDIO,
        "category": "음성가이드",
        "intensity": 1,
        "asset_ref": "counselor_guide_02.mp3",
        "media_url": f"{_CDN_GUIDE}/counselor_guide_02.mp3",
    },
]


def _is_demo_url(url: str) -> bool:
    return (not url) or any(h in url for h in _DEMO_HOSTS)


class Command(BaseCommand):
    help = "노출 자극 미디어 시드 데이터를 적재합니다."

    def handle(self, *args, **options):
        created = updated = 0
        for item in SEED_MEDIA:
            obj, was_created = ExposureMedia.objects.get_or_create(
                title=item["title"], defaults=item
            )
            if was_created:
                created += 1
                self.stdout.write(self.style.SUCCESS(f"생성: {obj.title}"))
            elif _is_demo_url(obj.media_url):
                # 관리자가 실제 URL을 넣지 않은 데모 행만 최신 클립으로 갱신.
                obj.media_url = item["media_url"]
                obj.media_type = item["media_type"]
                obj.intensity = item["intensity"]
                obj.asset_ref = item["asset_ref"]
                obj.save(update_fields=["media_url", "media_type", "intensity", "asset_ref"])
                updated += 1
                self.stdout.write(f"갱신: {obj.title}")
            else:
                self.stdout.write(f"보존(관리자 URL): {obj.title}")

        self.stdout.write(
            self.style.SUCCESS(
                f"시드 완료. 신규 {created} / 갱신 {updated} / 전체 "
                f"{ExposureMedia.objects.count()}건"
            )
        )

        # 대처 행동 카탈로그(가이드 표) 적재 — 제목 기준 멱등, 사용자 추가분은 보존.
        act_created = act_updated = 0
        for title, category, direction, effort, note in COPING_CATALOG:
            obj, was_created = CopingAction.objects.get_or_create(
                title=title,
                defaults={
                    "category": category,
                    "direction": direction,
                    "effort": effort,
                    "note": note,
                },
            )
            if was_created:
                act_created += 1
            elif not obj.is_custom:
                obj.category = category
                obj.direction = direction
                obj.effort = effort
                obj.note = note
                obj.save(update_fields=["category", "direction", "effort", "note"])
                act_updated += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"행동 카탈로그. 신규 {act_created} / 갱신 {act_updated} / 전체 "
                f"{CopingAction.objects.count()}건"
            )
        )

        # 회복 학습 노트 카탈로그 — key 기준 멱등, 사용자 메모(note)는 절대 덮지 않음.
        lc_created = lc_updated = 0
        for (key, group_no, group_title, title, title_en,
             originator, summary, connection) in LEARNING_CATALOG:
            fields = {
                "group_no": group_no,
                "group_title": group_title,
                "title": title,
                "title_en": title_en,
                "originator": originator,
                "summary": summary,
                "connection": connection,
            }
            obj, was_created = LearningConcept.objects.get_or_create(
                key=key, defaults=fields
            )
            if was_created:
                lc_created += 1
            else:
                # 큐레이션 내용만 갱신하고 note 는 보존.
                for f, v in fields.items():
                    setattr(obj, f, v)
                obj.save(update_fields=list(fields.keys()))
                lc_updated += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"학습 노트 카탈로그. 신규 {lc_created} / 갱신 {lc_updated} / 전체 "
                f"{LearningConcept.objects.count()}건"
            )
        )
