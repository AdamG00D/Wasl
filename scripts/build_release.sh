#!/usr/bin/env bash
# بناء نسخة Release موقّعة ومشوّشة وتنظيمها في مجلد Releases (جوه المشروع، برا Git):
#   Releases/<X.Y>v/Wasl_<X.Y>v.apk + Release_Notes.txt
#   Releases/Wasl.apk  ← آخر إصدار
set -euo pipefail

cd "$(dirname "$0")/.."

# جافا النظام (25) مفيهاش javac — بنستخدم JDK 21 لو موجود
JDK21="$HOME/Downloads/Files/toolchains/jdk-21.0.12.1+1"
if [ -z "${JAVA_HOME:-}" ] && [ -d "$JDK21" ]; then
  export JAVA_HOME="$JDK21" PATH="$JDK21/bin:$PATH"
fi

if [ ! -f ../Signing_Key/key.properties ]; then
  echo "⚠️  مفتاح التوقيع مش موجود في ../Signing_Key — شوف README هناك"
  exit 1
fi

# 1.0.0+1 ← 1.0
VERSION=$(grep '^version:' pubspec.yaml | sed -E 's/version: ([0-9]+)\.([0-9]+).*/\1.\2/')
NOTES="release_notes/${VERSION}v.txt"
if [ ! -f "$NOTES" ]; then
  echo "⚠️  اكتب ملاحظات الإصدار الأول في: $NOTES"
  exit 1
fi

flutter pub get
flutter analyze
flutter test
flutter build apk --release --obfuscate --split-debug-info="build/symbols/${VERSION}"

APK=build/app/outputs/flutter-apk/app-release.apk
REL="Releases"
OUT="$REL/${VERSION}v"
mkdir -p "$OUT"
cp "$APK" "$OUT/Wasl_${VERSION}v.apk"
cp "$NOTES" "$OUT/Release_Notes.txt"
cp "$APK" "$REL/Wasl.apk"

# نقفل Gradle عشان ميفضلش ماسك ~2 جيجا رام
(cd android && ./gradlew --stop >/dev/null 2>&1) || true

echo
echo "✅ الإصدار ${VERSION}v جاهز:"
echo "   $(realpath "$OUT/Wasl_${VERSION}v.apk")"
echo "   $(realpath "$REL/Wasl.apk")  (آخر إصدار)"
