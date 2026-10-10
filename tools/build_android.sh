#!/usr/bin/env bash
# Builds Pasal Sort for Android.
#
#   tools/build_android.sh test      -> build/android/pasal-sort-test.apk  (debug, test ads; install on your phone)
#   tools/build_android.sh release   -> build/android/pasal-sort.aab       (signed with YOUR upload key, for Play)
#
# Needs: Godot 4.7.2 + its export templates, Android SDK (~/Library/Android/sdk), JDK 17 (Homebrew openjdk@17).
# Release signing: create the upload key once (keep it and its password safe, outside this repo):
#   keytool -genkeypair -v -keystore ~/pasal-sort-upload.keystore -alias pasalsort -keyalg RSA -keysize 2048 -validity 10000
# This script asks for the password; it is never written to disk.
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
# Java on this Mac times out on IPv6 routes that curl handles fine; force IPv4 for Gradle's downloads
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.net.preferIPv4Stack=true"
GRADLE_ZIP="$HOME/.gradle/local-dists/gradle-8.11.1-bin.zip"   # optional local copy (fetched with curl)
KEYSTORE="${PASAL_KEYSTORE:-$HOME/pasal-sort-upload.keystore}"
ALIAS="${PASAL_KEY_ALIAS:-pasalsort}"
MODE="${1:-test}"

cd "$ROOT"
mkdir -p build/android

# Godot's Android build template (res://android/build), needed for Gradle builds and the AdMob plugin.
# Same as the editor's Project -> Install Android Build Template: unpack android_source.zip + record the version.
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
if [ ! -f android/build/build.gradle ]; then
  echo "Installing the Android build template..."
  mkdir -p android/build
  unzip -q -o "$TEMPLATES/android_source.zip" -d android/build
  echo "4.7.2.stable" > android/.build_version
  touch android/build/.gdignore
  # slow connections: give the one-time Gradle download 10 minutes instead of 10 seconds
  sed -i '' '/^networkTimeout=/d' android/build/gradle/wrapper/gradle-wrapper.properties
  echo "networkTimeout=600000" >> android/build/gradle/wrapper/gradle-wrapper.properties
fi
if [ -f "$GRADLE_ZIP" ]; then   # use the local Gradle zip instead of the wrapper's own download
  sed -i '' "s|^distributionUrl=.*|distributionUrl=file\\\\:$GRADLE_ZIP|" android/build/gradle/wrapper/gradle-wrapper.properties
fi

case "$MODE" in
  test)
    "$GODOT" --headless --path . --export-debug "Android APK (phone test)" build/android/pasal-sort-test.apk
    echo "Built build/android/pasal-sort-test.apk"
    echo "Install it: $ANDROID_HOME/platform-tools/adb install -r build/android/pasal-sort-test.apk"
    ;;
  release)
    if [ ! -f "$KEYSTORE" ]; then
      echo "No upload keystore at $KEYSTORE. Create it first (see the top of this script)." >&2
      exit 1
    fi
    read -r -s -p "Upload keystore password: " PASS; echo
    GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" \
    GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS" \
    GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS" \
      "$GODOT" --headless --path . --export-release "Android" build/android/pasal-sort.aab
    unset PASS
    echo "Built build/android/pasal-sort.aab. Upload it in Play Console → Testing → Closed testing."
    echo "Before the next upload, raise version/code in export_presets.cfg (Play rejects a repeated code)."
    ;;
  *)
    echo "usage: tools/build_android.sh [test|release]" >&2
    exit 2
    ;;
esac
