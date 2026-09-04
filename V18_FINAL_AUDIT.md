# Tayyib Word v19 — Final MS Word 2007-oriented engine pass

This release is the crash/build-safety packaging pass on the v18 baseline. It keeps the Word 2007-style ribbon structure while strengthening the document engine areas that were still represented only superficially.

## Included in this batch
- Word 2007-style ribbon tabs: Office, Home, Insert, Page Layout, References, Mailings, Review, View.
- Page Layout controls for themes/fonts, page setup, page background, paragraph settings, arrange, line numbers, gridlines, hyphenation, first-page/odd-even headers, and layout preview.
- Rich-text editing through Flutter Quill with persistence in `.twd`.
- Undo/redo history and snapshot-based tracked changes.
- Comments, citations, footnotes/endnotes, TOC/index helpers, bookmarks, bibliography helper, mail-merge preview/finish, protection, find/replace, spelling helper, and compare helper.
- Page-size/orientation/margins/columns, watermark, page color/borders, headers/footers, first/even-page behavior, page numbering, page-break handling and improved word-aware pagination preview.
- Rulers, zoom, line-number preview, and document status information.
- Tables with add/remove rows/columns, table settings, selectable cell ranges, horizontal cell merging/splitting, persisted merge ranges, and DOCX `gridSpan` export for merged horizontal cells.
- DOCX recovery now also reconstructs basic tables and reads `word/header1.xml` / `word/footer1.xml` when present, instead of flattening all table content into plain text.
- Picture size/crop/wrap/arrange/position/rotation controls, text boxes, shapes, WordArt, SmartArt, charts, equations, drop caps, signatures, Quick Parts, symbols, dates and times.
- PDF and DOCX export paths remain included.
- Main application ID/namespace: `com.tayyibword.app`.
- Official Tayyib Word blue/gold logo asset retained.

## Validation performed here
- Dart source structural delimiter check: parentheses, braces and brackets balanced.
- ZIP integrity test: passed.
- Source/package version updated to `1.0.0+19`.

## Important build note
The supplied environment does not contain the Flutter SDK/Android build toolchain, so an APK compile/install test cannot honestly be claimed from this environment. The project is packaged for the user's AIDE/Flutter build workflow.

## Engineering boundary
This is a substantially expanded Word-like editor, not a claim of Microsoft's proprietary Word engine. Full native OOXML round-trip fidelity, VBA/macros, real-time collaboration, and Microsoft's complete layout/revision compositor would require a much larger independent engine and cannot be truthfully described as already implemented.

## Crash/build safety fixes in v19
- Added the missing Flutter SDK dependency `flutter_localizations`, required by the imported localization delegates in `lib/main.dart`.
- Removed environment-specific `android/local.properties` so the ZIP does not force the build to use a stale Termux SDK/Flutter path.
- Android manifest keeps Impeller explicitly disabled to reduce startup-crash risk on affected Android devices.


## V20 CRASH/PORTABILITY PASS
- Removed the Termux-only `android.aapt2FromMavenOverride` setting from `android/gradle.properties`.
- Kept the Flutter architecture and FlutterActivity; no WebView conversion.
- Kept Impeller disabled as a conservative startup-crash mitigation.
- Kept Android hardware acceleration enabled.
- Kept Flutter localization dependency declared.
- Version bumped to 1.0.0+20.
- No environment-specific `android/local.properties` is distributed.
- This archive has been statically checked only; an actual APK build/run still requires a Flutter build environment.


## V21 build-safety pass
- Removed invalid Expanded(height: ...) arguments by wrapping table cells in SizedBox(height: ...).
- Replaced questionable Material icon identifiers with stable built-in icons.
- Raised Dart SDK floor to 3.12.0 to match flutter_quill 11.5.1 requirements.
- Made Flutter SDK discovery support local.properties plus FLUTTER_ROOT/FLUTTER_HOME.
- Removed legacy android.newDsl=false and android.builtInKotlin=false overrides so modern AGP/Flutter tooling can use its defaults.
- Version: 1.0.0+21.
- This archive is statically audited only; an actual Flutter build still requires a Flutter SDK/toolchain.
