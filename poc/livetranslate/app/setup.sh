#!/usr/bin/env bash
#
# Flutter 기기 빌드 준비 스크립트.
#
# 이 PoC는 lib/ 와 pubspec.yaml 만 포함하므로, 빌드 전에 플랫폼 폴더
# (android/ios)를 한 번 생성하고 마이크/인터넷 권한을 주입해야 한다.
# 이 스크립트가 그 과정을 자동화한다(여러 번 실행해도 안전).
#
# 사용법:
#   cd poc/livetranslate/app
#   ./setup.sh
#   flutter run --dart-define=RELAY_BASE_URL=ws://10.0.2.2:8080
#
set -euo pipefail
cd "$(dirname "$0")"

command -v flutter >/dev/null || { echo "flutter SDK가 필요합니다."; exit 1; }

echo "==> 플랫폼 폴더 생성(lib/pubspec 유지)"
flutter create --platforms=android,ios --project-name livetranslate_poc .

MANIFEST="android/app/src/main/AndroidManifest.xml"
echo "==> Android 권한 주입: $MANIFEST"
if ! grep -q "RECORD_AUDIO" "$MANIFEST"; then
  perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.RECORD_AUDIO"/>#' "$MANIFEST"
  echo "   추가됨(INTERNET, RECORD_AUDIO)"
else
  echo "   이미 존재 — 건너뜀"
fi

PLIST="ios/Runner/Info.plist"
echo "==> iOS 마이크 권한 주입: $PLIST"
if [ -f "$PLIST" ] && ! grep -q "NSMicrophoneUsageDescription" "$PLIST"; then
  perl -0pi -e 's#(<dict>)#$1\n\t<key>NSMicrophoneUsageDescription</key>\n\t<string>실시간 통역을 위해 마이크를 사용합니다.</string>#' "$PLIST"
  echo "   추가됨(NSMicrophoneUsageDescription)"
else
  echo "   이미 존재하거나 파일 없음 — 건너뜀"
fi

echo "==> 생성된 기본 위젯 테스트 제거(존재하지 않는 MyApp 참조)"
rm -f test/widget_test.dart

echo "==> minSdk 24 보정 (record/flutter_sound 요구)"
for GRADLE in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$GRADLE" ] || continue
  # Groovy/Kotlin DSL 및 flutter.minSdkVersion/숫자 형태 모두 대응.
  perl -0pi -e '
    s/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion 24/g;
    s/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 24/g;
    s/minSdkVersion\s+\d+/minSdkVersion 24/g;
    s/minSdk\s*=\s*\d+/minSdk = 24/g;
  ' "$GRADLE"
  echo "   patched: $GRADLE"
done

echo "==> 의존성 설치"
flutter pub get

cat <<'DONE'

준비 완료 ✅

실행 예시:
  # 안드로이드 에뮬레이터 + 같은 PC의 로컬 릴레이
  flutter run --dart-define=RELAY_BASE_URL=ws://10.0.2.2:8080

  # 실기기(같은 와이파이) → PC LAN IP 지정
  flutter run --dart-define=RELAY_BASE_URL=ws://192.168.0.x:8080

  # 해외 릴레이(운영)
  flutter run \
    --dart-define=RELAY_BASE_URL=wss://my-relay.example.com \
    --dart-define=RELAY_TOKEN=설정한토큰

  # APK 빌드
  flutter build apk --release \
    --dart-define=RELAY_BASE_URL=wss://my-relay.example.com \
    --dart-define=RELAY_TOKEN=설정한토큰

빌드가 minSdk 관련으로 실패하면 android/app/build.gradle(.kts)의
minSdkVersion 을 24 로 올린다(record/flutter_sound 요구사항).
DONE
