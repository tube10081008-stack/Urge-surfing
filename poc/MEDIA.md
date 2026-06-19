# 🎬 노출 자극 미디어 수집·등록 가이드

앱은 미디어를 **앱에 내장하지 않고**, 각 자극의 `media_url`(스트리밍 URL)을 재생한다.
따라서 미디어를 추가/교체할 때 **앱 재빌드가 필요 없고**, Django 관리자에서 URL만 바꾸면 된다.

```
[유튜브/소스]  --yt-dlp-->  [짧게 컷·정리]  --업로드-->  [호스팅 URL]  --관리자 등록-->  [앱 재생]
```

> ⚠️ 현재 시드의 URL은 **재생 파이프라인 증명용 공개 샘플**(도박 콘텐츠 아님)이다.
> 실제 도박 자극 URL로 관리자에서 교체해 사용한다.
> 공개 GitHub 저장소엔 저작권 미디어를 올리지 말 것(DMCA로 저장소가 내려갈 수 있음).

## 1. 수집 (yt-dlp)
```bash
pip install -U yt-dlp
# 480p mp4 한 편 받기
yt-dlp -f "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
  -o "slot_%(id)s.%(ext)s" "<유튜브_URL>"

# 10~60초로 컷 + 무음 추출 등은 ffmpeg
ffmpeg -i slot_xxx.mp4 -ss 00:00:05 -t 00:00:30 -c copy slot_clip.mp4   # 5초~35초 구간
ffmpeg -i casino.mp4 -vn -acodec libmp3lame chips.mp3                    # 오디오만 추출
```
**팁:** ERP 효과를 위해 자극을 **강도별(1~5)** 로 나눠 준비 (약: 짧고 정적 → 강: 길고 역동적).

## 2. 호스팅 (URL 확보)
파일을 공개 접근 가능한 곳에 올려 직접 URL을 얻는다. 추천:
- **Cloudflare R2** (무료 10GB, S3 호환, 커스텀 도메인) — 권장
- **Backblaze B2** (무료 10GB)
- 직접 서버/NAS의 정적 파일 (HTTPS 필요)

요건: `https://`로 시작하고, **mp4(H.264)/mp3/jpg·png** 처럼 브라우저·ExoPlayer가 바로 재생 가능한 형식.

## 3. 등록 (Django 관리자)
1. `https://urge-surfing-api.onrender.com/admin/` 접속 (관리자 계정 필요 — 아래)
2. **Core → 노출 자극 미디어** → 항목 추가/수정
3. 입력: `제목`, `미디어 유형`(video/audio/image), `카테고리`, `강도(1~5)`, **`미디어 URL`**, (선택)`주의 문구`
4. 저장 → 앱에서 바로 반영 (앱 재시작/홈 새로고침)

### 관리자 계정 만들기
Render 대시보드 → 서비스 → **Shell** 탭에서:
```bash
python manage.py createsuperuser
```
(또는 로컬에서 `DATABASE_URL=<운영DB> python manage.py createsuperuser`)

## 4. 앱 동작
- `media_url`이 있으면 → **실제 재생**(영상=비디오, 오디오=사운드, 이미지=표시)
- 비어 있거나 재생 실패 → **플레이스홀더로 안전 대체**
- 노출 전 **콘텐츠 경고** 다이얼로그 표시(맞춤 문구는 `주의 문구` 필드)
- 재생 중에도 **SOS(1336)** 상시 노출, 60초 자동 종료 또는 직접 종료 → 파도타기

→ 관련: [배포 가이드](./DEPLOY.md) · [PoC README](./README.md)
