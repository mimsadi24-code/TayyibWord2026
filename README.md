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

## Build verification note
This source package has been statically checked and the ZIP archive has been integrity-tested. A Flutter/Dart toolchain is not available in this packaging environment, so the Android APK itself must be compiled in AIDE/Flutter environment before release.


## v10 document engine improvements
- Saves and restores the Flutter Quill Delta, so character-level rich-text formatting survives `.twd` save/open.
- DOCX export reads the Quill Delta and writes separate OOXML runs for bold, italic, underline, strike, superscript/subscript, font and size.
- Comments now keep selection start/end offsets and timestamps instead of only storing a text string.
- Track Changes now stores before/after document snapshots and supports Accept All / Reject All.
- Existing legacy documents remain loadable through the plain-text fallback.

This release is source-verified only in this environment; Flutter/Gradle compilation still requires a Flutter-capable build environment.

## v12
See `V12_CHANGES.md` for the latest feature-completion pass.
