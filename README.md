App i18n
===

A lightweight CLI tool to streamline and unify the i18n workflow for multiple iOS/macOS apps.

## Key Features

- Bidirectional conversion: `.strings` ⇄ `.lproj` folders
- `.lproj` structure optimized for AI batch translation
- Centralized management of localization files across multiple apps
- CLI-first, scriptable & CI/CD friendly

## .xcstrings vs .lproj

| Feature            | .xcstrings (String Catalogs)          | .lproj (Traditional)               |
|--------------------|---------------------------------------|-------------------------------------|
| Xcode Experience   | Excellent (auto-extract, visual status, missing/stale flags) | Basic (manual maintenance)         |
| Git Conflicts      | High (single file, unstable order)    | Very low (per-language files)      |
| Team/Outsourced Translation | Poor                               | Excellent (independent per language) |
| AI Batch Translation | Average                             | Best (clean structure, easy to feed AI) |
| Apple Recommendation | Strongly recommended (Xcode 15+ future standard) | Still fully supported underlying   |

## Why appi18n?

- 🔁 Seamless `.strings` ↔ `.lproj` conversion
- 🤖 Best format for feeding AI translation engines
- 📦 Manage i18n for multiple apps in one place
- ⚡ Lightweight, fast, CLI-driven
- 🛠 Reduces missed translations & Git pain

Install: `brew install jaywcjlove/tap/appi18n` (coming soon)  
Docs & Examples: https://github.com/jaywcjlove/appi18n