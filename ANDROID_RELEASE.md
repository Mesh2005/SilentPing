# SilentPing 0.2.0 Android preview

This preview includes the new welcome and loading screens, account creation and sign-in, circle selection, private invitations, and three foreground ping patterns.

## Download and install

Download `SilentPing-0.2.0-android.apk` from the Assets section of this repository's GitHub release. Open it on your Android phone and allow installation from your browser or file manager when Android asks. No Play Store purchase is needed.

- Requires Android 7.0 (API 24) or newer.
- Universal APK includes armeabi-v7a, arm64-v8a and x86_64 native libraries.
- Requires internet and a separate account on each phone.
- Keep SilentPing visible and the screen awake to receive pings. Background and locked-phone delivery are not enabled.
- Vibration depends on the phone's hardware and settings. Other Android models still require physical-device testing.
- This preview uses the existing local Android debug signing key, even though the APK is compiled in release mode. It can update the prototype installed from this computer. It is not a production-signed Play Store release; future builds must retain the same signing identity to update existing installations.

## Build

```powershell
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --dart-define=ENABLE_ANDROID_PUSH=false
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. Do not commit APK binaries or private signing keys to the source repository. Upload the APK as a GitHub release asset.
