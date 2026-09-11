# Tayyib Word Flutter

Desktop-class fixed-width Microsoft Word inspired UI for Android. Ribbon is horizontally scrollable rather than responsive.

## Run
1. Install Flutter SDK.
2. Extract this project.
3. Run `flutter create .` to generate the platform scaffold.
4. Run `flutter pub get`.
5. Connect Android device and run `flutter run`.
6. Release APK: `flutter build apk --release`.

The UI is an independent recreation; Microsoft proprietary source code/assets are not included.

## Crash FIX v3
- Android Impeller is disabled via AndroidManifest.xml to avoid renderer/GPU startup crashes.
- First-frame splash no longer decodes the logo asset; this isolates asset-decoder startup crashes.
- The bundled logo asset is a real PNG.
- Duplicate Gradle JVM argument removed.
