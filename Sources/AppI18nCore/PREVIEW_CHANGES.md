# Preview And Extraction Notes

This document summarizes the recent changes made under `Sources/` and `Tests/`.

## 1. Extract now copies app icons

`extract(projectPath:)` now looks for a `128x128` PNG inside `.xcassets/*.appiconset/Contents.json`.

Behavior:
- `.xcstrings` files are still copied into `i18n/source/<app>/`
- when a matching icon is found, it is also copied to `i18n/source/<app>/logo.png`

Why:
- `preview` needs a stable icon file per app
- the extracted logo becomes the single source for HTML preview branding

## 2. to-lproj now keeps app-wide language coverage consistent

`toLproj()` no longer limits each `.xcstrings` file to only the languages already present inside that file.

Behavior:
- language generation is now based on the union of:
  - all languages found across the app's `.xcstrings` files
  - all languages already present under `i18n/lproj/<app>/*.lproj`
- this means dependency package localization files follow the same app-level language set as the main app

Why:
- package view localization should not lag behind the main app just because one dependency `.xcstrings` file has fewer language entries

## 3. preview now bundles logos into the output folder

`previewHTML(apps:outputPath:)` now copies each app logo into the generated site output.

Behavior:
- logos are copied to `assets/logos/<app-page-slug>.png`
- generated `index.html` and per-app pages reference the copied asset inside the output directory
- the generated site no longer depends on relative links back to `i18n/source/.../logo.png`

Why:
- custom output directories should be self-contained
- generated previews should be easier to move, publish, and inspect

## 4. preview homepage visual changes

The homepage was redesigned to improve scanability and reduce layout friction.

Changes:
- app cards now display icon + app name + summary metadata
- language completion uses a vertical list with compact progress rows instead of a table
- homepage no longer needs horizontal scrolling for language status
- dark theme styling was introduced and later refined to reduce heavy shadows and oversized radii
- the homepage `.card-table` wrapper was simplified to only keep outer spacing and top padding
- the `i18n Preview` eyebrow label is forced to stay on one line
- app detail page `body` now uses `min-height: 100vh`

## 5. Tests added or expanded

Tests now cover:
- app icon extraction into `logo.png`
- app-wide language propagation for dependency `.xcstrings`
- preview logo copying into custom output directories
- updated preview homepage structure

## Verification

Verified with:

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache swift test
```
