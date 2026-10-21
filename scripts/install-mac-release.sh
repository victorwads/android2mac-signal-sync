#!/bin/bash
# Local Release build + ad-hoc signature + installation. No Apple account required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MAC="$ROOT/mac"
NAME="Android 2 Mac Sinal Sync.app"
BUNDLE_ID="dev.wads.phone2mac.signalsync"
DEST="/Applications/$NAME"
BUILD_ONLY=false
case "${1:-}" in
  --build-only) BUILD_ONLY=true ;;
  --help|-h) printf 'Usage: %s [--build-only]\nBuild Release, sign ad-hoc, then install in /Applications. Replaces the existing app without backups.\n' "$0"; exit 0 ;;
  "") ;;
  *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS is required.' >&2; exit 1; }
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen' >&2; exit 1; }
xcodebuild -version
(cd "$MAC" && xcodegen generate)
xcodebuild -quiet -project "$MAC/PhoneSignalSync.xcodeproj" \
  -scheme PhoneSignalSync -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$MAC/.build" CODE_SIGNING_ALLOWED=NO build
APP="$MAC/.build/Build/Products/Release/$NAME"
[[ -d "$APP" && ! -L "$APP" ]] || { echo 'Expected build bundle is missing.' >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")" == "$BUNDLE_ID" ]] || exit 1
# Sign the final standalone app, preserving the sandbox/network entitlements.
/usr/bin/codesign --force --sign - --timestamp=none \
  --entitlements "$MAC/Generated/PhoneSignalSync.entitlements" "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
if "$BUILD_ONLY"; then
  printf 'Signed Release ready: %s\n' "$APP"
  exit 0
fi
[[ -d /Applications && ! -L /Applications && "$DEST" == "/Applications/Android 2 Mac Sinal Sync.app" ]] || exit 1
[[ ! -L "$DEST" ]] || { echo 'Refusing to replace a symlink.' >&2; exit 1; }
if [[ -e "$DEST" ]]; then
  [[ -d "$DEST" && "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist")" == "$BUNDLE_ID" ]] || {
    echo 'Destination belongs to another app; refusing replacement.' >&2; exit 1;
  }
fi
# Stop only the exact installed executable; leave Xcode/development copies alone.
PROCESS_PATTERN="^/Applications/Android 2 Mac Sinal Sync[.]app/Contents/MacOS/Android 2 Mac Sinal Sync($| )"
PIDS="$(/usr/bin/pgrep -f "$PROCESS_PATTERN" || true)"
if [[ -n "$PIDS" ]]; then
  echo "Stopping installed app…"
  /bin/kill -TERM $PIDS 2>/dev/null || true
  for attempt in {1..30}; do
    /usr/bin/pgrep -f "$PROCESS_PATTERN" >/dev/null || break
    /bin/sleep 0.1
  done
  PIDS="$(/usr/bin/pgrep -f "$PROCESS_PATTERN" || true)"
  if [[ -n "$PIDS" ]]; then
    echo "App did not exit; forcing termination…"
    /bin/kill -KILL $PIDS 2>/dev/null || true
    for attempt in {1..20}; do
      /usr/bin/pgrep -f "$PROCESS_PATTERN" >/dev/null || break
      /bin/sleep 0.1
    done
  fi
  if /usr/bin/pgrep -f "$PROCESS_PATTERN" >/dev/null; then
    echo "App is still running; refusing to replace it." >&2
    exit 1
  fi
fi
privileged() {
  if [[ -w /Applications ]]; then "$@"; else /usr/bin/sudo "$@"; fi
}
if [[ -e "$DEST" ]]; then
  # Exact destination has already been validated above; never merge stale bundle files.
  [[ "$DEST" == "/Applications/Android 2 Mac Sinal Sync.app" && ! -L "$DEST" ]] || exit 1
  privileged /bin/rm -rf -- "$DEST"
fi
privileged /usr/bin/ditto "$APP" "$DEST"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$DEST"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist")" == "$BUNDLE_ID" ]] || exit 1
printf 'Installed: %s\n' "$DEST"
/usr/bin/open "$DEST"
printf 'Opened: %s\nLocal ad-hoc signature only; not notarized for distribution.\n' "$DEST"
