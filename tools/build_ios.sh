#!/bin/bash
# iOS build.
#
#   tools/build_ios.sh            # export the Xcode project and open it in Xcode
#   tools/build_ios.sh upload     # export, archive and upload to App Store Connect / TestFlight (no Xcode clicks)
#
# Upload needs the App Store Connect API key in ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8, the
# "Apple Distribution" certificate in the login keychain and the "Pasal Sort App Store (local)" provisioning
# profile (tools/ios_export_options.plist). The version and build number are in export_presets.cfg (preset
# "iOS": application/short_version, application/version); keep them in step with Android. App Store
# Connect rejects a build number it has already seen.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
xcodebuild -version >/dev/null 2>&1 || { echo "Xcode not selected: sudo xcode-select -s /Applications/Xcode.app"; exit 1; }
grep -q '^application/app_store_team_id="[A-Z0-9]\{10\}"' export_presets.cfg \
	|| { echo "Set your Team ID in export_presets.cfg (application/app_store_team_id)"; exit 1; }
# Never ship Google's test AdMob IDs or placeholders.
grep -q '^general/ios/app_id="ca-app-pub-7387045424284544~' project.godot && ! grep -q "XXXXXXXX" data/ads.json \
	|| { echo "AdMob iOS IDs are not filled in (project.godot [admob], data/ads.json)"; exit 1; }

rm -rf build/ios
mkdir -p build/ios
"$GODOT" --headless --path . --export-release "iOS" build/ios/PasalSort.ipa 2>&1 | grep -E "ERROR|failed" || true
[ -d build/ios/PasalSort.xcodeproj ] || { echo "export failed"; exit 1; }
echo "Exported build/ios/PasalSort.xcodeproj"
if [ "${1:-}" != "upload" ]; then
	[ "${NO_OPEN:-}" ] || open build/ios/PasalSort.xcodeproj
	exit 0
fi
KEY_ID="${ASC_KEY_ID:-R8FBS6AHU4}"
ISSUER="${ASC_ISSUER_ID:-174378ae-c14b-45e2-a860-e56724989612}"
AUTH=(-authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER")
cd build/ios
echo "== archiving"
xcodebuild -project PasalSort.xcodeproj -scheme PasalSort -configuration Release -destination "generic/platform=iOS" \
	-archivePath PasalSort.xcarchive archive -allowProvisioningUpdates "${AUTH[@]}" > archive.log 2>&1 \
	|| { grep -E "error:" archive.log | head; exit 1; }
echo "== uploading"
xcodebuild -exportArchive -archivePath PasalSort.xcarchive -exportOptionsPlist ../../tools/ios_export_options.plist \
	-exportPath export "${AUTH[@]}" > upload.log 2>&1 || { grep -iE "error" upload.log | head; exit 1; }
grep -E "Upload succeeded" upload.log && echo "Processing on App Store Connect takes 5-30 minutes."
