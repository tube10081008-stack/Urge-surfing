"""
시드 데이터 적재 커맨드.

사용법: python manage.py seed

노출 자극 미디어(슬롯/스포츠베팅/경마 등)를 적재한다.
멱등성을 위해 title 기준으로 get_or_create 사용.
"""
from django.core.management.base import BaseCommand

from core.models import ExposureMedia


SEED_MEDIA = [
    {
        "title": "온라인 슬롯머신 릴 영상",
        "media_type": ExposureMedia.MediaType.VIDEO,
        "category": "슬롯",
        "intensity": 4,
        "asset_ref": "assets/exposure/slot_reel.mp4",
    },
    {
        "title": "스포츠 베팅 배당률 화면",
        "media_type": ExposureMedia.MediaType.IMAGE,
        "category": "스포츠베팅",
        "intensity": 3,
        "asset_ref": "assets/exposure/sports_odds.png",
    },
    {
        "title": "경마 경주 실황 영상",
        "media_type": ExposureMedia.MediaType.VIDEO,
        "category": "경마",
        "intensity": 5,
        "asset_ref": "assets/exposure/horse_race.mp4",
    },
    {
        "title": "카지노 칩 사운드",
        "media_type": ExposureMedia.MediaType.AUDIO,
        "category": "카지노",
        "intensity": 2,
        "asset_ref": "assets/exposure/casino_chips.mp3",
    },
]


class Command(BaseCommand):
    help = "노출 자극 미디어 시드 데이터를 적재합니다."

    def handle(self, *args, **options):
        created_count = 0
        for item in SEED_MEDIA:
            obj, created = ExposureMedia.objects.get_or_create(
                title=item["title"],
                defaults=item,
            )
            if created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(f"생성: {obj.title}"))
            else:
                self.stdout.write(f"이미 존재: {obj.title}")

        self.stdout.write(
            self.style.SUCCESS(
                f"시드 완료. 신규 {created_count}건 / 전체 {ExposureMedia.objects.count()}건"
            )
        )
