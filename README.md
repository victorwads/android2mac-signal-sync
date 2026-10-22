# Android 2 Mac Sinal Sync

Your Android phone’s cellular signal and battery in your Mac’s menu bar.

[Português (Brasil)](<README.pt.md>) · [Logo and icon generation](<assets/README.md>)

## Features

- Native Kotlin Android app with explicit start/stop and foreground notification.
- Cellular signal level, dBm when available, carrier and network type.
- Battery percentage and charging status.
- Local discovery with DNS-SD / Bonjour and manual private IPv4 fallback.
- Multiple phones shown simultaneously in the menu bar, each with a saved nickname, 0–4 signal bars, radio technology and battery.
- 4G, 4G+, 5G and 5G+ labels when reported by Android; a lightning indicator while charging.
- Two-second polling, disconnected states and modem reading age.
- Pairing tokens stored in macOS Keychain. No cloud account or backend.

**Development build:** transport uses authenticated HTTP, not encrypted TLS. Use trusted networks only. An observer able to inspect traffic could capture the token and status. Not suitable for public Wi-Fi. Signed distribution and encrypted transport are not implemented. Mac traffic accounting is not implemented yet.

## Connect

1. Open Android: monitoring starts automatically. On first launch, grant phone access and allow notifications.
2. Connect the Mac and phone to the same Wi-Fi, or connect the Mac to the Android hotspot.
3. Open the Mac app and allow **Local Network** access.
4. Open the discovered phone’s submenu, choose **Connect / approve on phone…**, compare the six-digit code on both devices, then tap **Permitir** on Android. No token typing.
5. Choose **Set nickname…** to name it (for example Leo or Victor). Repeat for another phone; each phone has its own independent menu-bar item. Click a phone to see its details directly. The per-phone toggles **Show name**, **Show percentage**, **Show battery icon** and **Show WiFi** are saved on this Mac. **Show WiFi is off by default**: the bar prioritizes cellular technology even when the phone uses Wi-Fi. Enable it to replace the technology label with WiFi; the bars still represent cellular signal. Unknown network technology is omitted in the bar and explained in the details. Transient connection failures retain the last reading for up to 60 seconds; the details show its age and retry state. After 60 seconds without a successful response the phone appears disconnected. Revoked access is cleared immediately. Nicknames are saved on the Mac.

If discovery is blocked, use **Add phone by IP…** with the Android IP and port, then approve on Android. On an Android hotspot, the phone’s IP is usually the **Router** address in the Mac Wi-Fi details, not the Mac’s own address. The app shows candidate IPs; never assume a fixed address. Port may change after restarting monitoring.

Wi-Fi RSSI in macOS describes the Mac-to-hotspot link, **not** cellular reception. Polling every two seconds does not force the modem to update; check the displayed reading age.

## Build macOS

Requires macOS 13+, full Xcode and XcodeGen 2.44+.

```sh
brew install xcodegen
cd mac
xcodegen generate
xcodebuild -project PhoneSignalSync.xcodeproj \
  -scheme PhoneSignalSync -configuration Debug \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
open ".build/Build/Products/Debug/Android 2 Mac Sinal Sync.app"
```

Or open the generated Xcode project and run the PhoneSignalSync scheme. These CLI builds are unsigned local development builds.

## Install a local macOS Release

From the repository root:

```sh
./scripts/install-mac-release.sh
```

The [installer](<scripts/install-mac-release.sh>) regenerates the Xcode project, builds Release, signs it ad-hoc with sandbox entitlements, verifies the signature and installs in /Applications. The installed process is stopped, the existing bundle is replaced without backups, and the new version is opened automatically. If /Applications requires administrator access, run the script from a terminal that can answer the sudo prompt. Use `--build-only` to compile and sign without installation. This is local signing, not Developer ID or Apple notarization.

## Build Android

Open android in Android Studio. Existing configuration: SDK 37, minimum API 24, AGP 9.4.1, Gradle 9.6.0, JVM toolchain 25. Configure your SDK using Android Studio or local.properties (ignored by Git).

```sh
cd android
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
# Authorized USB device:
./gradlew :app:installDebug
adb shell am start -n dev.wads.phone2mac.signalsync/.MainActivity
```

## Verification

Android checks (the connected test suite installs test APKs and resets test pairing data; use a development device):

```sh
cd android
./gradlew :app:testDebugUnitTest :app:lintDebug :app:connectedDebugAndroidTest
```

Mac checks, from the repository root:

```sh
swiftc mac/Sources/PhoneStore.swift mac/Tests/ProtocolChecks.swift -o /tmp/phone2mac-protocol-checks
/tmp/phone2mac-protocol-checks
swiftc mac/Sources/PhoneStore.swift mac/Tests/PollingChecks.swift -o /tmp/phone2mac-polling-checks
/tmp/phone2mac-polling-checks
swiftc mac/Sources/PhoneStore.swift mac/Sources/MenuBarIcon.swift mac/Tests/IconChecks.swift -o /tmp/phone2mac-icon-checks
/tmp/phone2mac-icon-checks
```

Verified: Android HTTP approval, unauthorized access, battery response and revocation on a physical Samsung; Mac production polling with two simulated phones, independent credentials, selection, denial and reconnection. Bonjour discovery and authenticated LAN telemetry were verified with a Galaxy A55. Simultaneous discovery of two physical phones and the complete visual pairing workflow still need manual acceptance testing.

## Limitations

- Manufacturer battery restrictions and sleep may delay/stop the service. No wake lock, boot autostart or guaranteed one-second execution.
- Default data SIM is selected at start; restart after switching it.
- On Android 12+, display overrides distinguish 4G+, 5G NSA and 5G+ when the modem/carrier exposes them. Older devices or missing overrides may show LTE / 4G instead. Ambiguous dBm readings are unavailable.
- Discovery may be blocked by multicast restrictions; manual connections still require reachable addresses.
- Android foreground service specialUse requires Play Store policy review, not guaranteed approval.
- No iOS or Windows app yet.

## Repository

- android: native app and Gradle wrapper.
- mac: native SwiftUI app and [XcodeGen configuration](<mac/project.yml>).
- assets: [canonical SVG logo](<assets/logo.svg>) and [platform icon generation guide](<assets/README.md>).

Bundle / application ID: `dev.wads.phone2mac.signalsync`.

Generated Xcode projects and build outputs are ignored; icon resources may be versioned.
