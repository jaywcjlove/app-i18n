[中文](./README.zh.md)

App i18n
===

Lightweight CLI tool for unifying and optimizing the internationalization (i18n) workflow across multiple apps. This project also contains my app internationalization files stored in the `i18n` directory.

`appi18n` helps you perform bidirectional conversion between `.xcstrings` and `.lproj`, making localization files more suitable for multi-person Git collaboration and AI batch translation, while maintaining seamless integration with Xcode.

## Why is it needed?

In scenarios with multi-person collaboration and AI-assisted translation, `.xcstrings` has these practical issues:

* Single-file structure, prone to Git conflicts
* Multiple languages concentrated in one file, not conducive to splitting translation tasks
* Large file size, consumes too many tokens when fed to AI in batch, can even cause translation interruptions

`appi18n` splits `.xcstrings` into a well-structured `.lproj` directory for easier maintenance and collaboration;  
it also supports converting back to `.xcstrings` to ensure seamless integration with the Xcode workflow, enjoying Xcode’s automatic extraction + visual translation status.

## Core Capabilities

* 🔁 Bidirectional conversion: `.xcstrings` ⇄ `.lproj`
* 🤖 `.lproj` structure better suited for AI batch translation
* 👥 Facilitates multi-person Git collaborative maintenance
* 📦 Supports unified management of localization files for multiple apps
* ⚡ CLI-first, easy to script and integrate with CI/CD

## `.xcstrings` vs `.lproj`

| Feature            | `.xcstrings`                          | `.lproj`                          |
|--------------------|---------------------------------------|-----------------------------------|
| Xcode Experience   | Excellent (auto extraction, visual translation status) | Average (requires manual maintenance) |
| Git Conflicts      | High (single file prone to conflicts) | Very low (language-independent files) |
| Team Collaboration | Not friendly                          | Very friendly                     |
| AI Batch Translation | Average                             | Excellent                         |
| Apple Recommendation | Strongly recommended (Xcode 15+)   | Compatible with underlying implementation |

## Value Brought by appi18n

* Reduces Git conflicts
* Lowers missed translations
* Improves AI translation efficiency
* Makes internationalization a repeatable, automatable process

## MyApp i18n

```shell
./i18n
├── lproj
│   ├── menuist
│   │   ├── en.lproj
│   │   │   ├── Menuist
│   │   │   │   ├── InfoPlist.strings
│   │   │   │   ├── Localizable.strings
│   │   │   ├── MenuistFinderExtension
│   │   │   │   ├── Info.plist
│   │   │   │   └── Localizable.strings
│   │   │   └── QuickLookPreview
│   │   │       ├── Info.plist
│   │   │       └── Localizable.strings
│   │   └── zh-Hans.lproj
│   │       ├── Menuist
│   │       │   ├── InfoPlist.strings
│   │       │   ├── Localizable.strings
│   │       ├── MenuistFinderExtension
│   │       │   ├── Info.plist
│   │       │   └── Localizable.strings
│   │       └── QuickLookPreview
│   │           ├── Info.plist
│   │           └── Localizable.strings
│   └── scap/
│       ├── en.lproj
│       │   ├── Localizable.strings
│       │   └── InfoPlist.strings
│       └── zh-Hans.lproj
│           ├── Localizable.strings
│           └── InfoPlist.strings
└── source
    ├── menuist
    │   ├── Menuist
    │   │   ├── InfoPlist.xcstrings
    │   │   ├── Localizable.xcstrings
    │   ├── MenuistFinderExtension
    │   │   ├── Info.plist
    │   │   └── Localizable.xcstrings
    │   └── QuickLookPreview
    │       ├── Info.plist
    │       └── Localizable.xcstrings
    └── scap
        ├── InfoPlist.xcstrings
        └── Localizable.xcstrings
```

## Installation (Coming Soon)

```bash
brew install jaywcjlove/tap/appi18n
```

## Build

Requires Swift 5.9+.

```bash
swift build -c release
# The executable will be at:
# .build/release/appi18n
```

## Test / Try Commands

```bash
# Show help:
swift run appi18n --help
# Extract `.xcstrings` from an Xcode project:
swift run appi18n extract /path/to/YourApp
# Convert `.xcstrings` to `.lproj`:
swift run appi18n to-lproj
# Update `.xcstrings` from `.lproj`:
swift run appi18n to-xcstrings
# Add a new language to one or more apps:
swift run appi18n langs menuist,scap fr
# List existing languages for an app:
swift run appi18n langs menuist
# List available recommended language codes:
swift run appi18n langs 
# List all system-provided language/region identifiers:
swift run appi18n langs --all
# Check translation status:
swift run appi18n status
# Clean empty/outdated `.lproj` files:
swift run appi18n clean
```

Release command:

```shell
$ env 'CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache' swift build -c release
$ tar -czf ./appi18n.tar.gz -C ./.build/arm64-apple-macosx/release appi18n
```

## App i18n CLI Command Help

```
Usage: appi18n <command> [options]

Commands:
  extract      Extract all .xcstrings from Xcode project to i18n/source
  to-lproj     Convert .xcstrings to .lproj structure (default output to i18n/lproj)
  langs        List languages for app(s) or add a language to app(s)
  to-xcstrings Update .lproj to .xcstrings (for importing to Xcode)
  status       Check translation status (missing / incomplete languages)
  clean        Clean outdated/empty .lproj files
  help         Show this help information
```

Examples:

```shell
appi18n extract /path/to/YourApp
appi18n to-lproj
appi18n langs menuist,scap fr
appi18n langs menuist
appi18n langs --all
appi18n to-xcstrings
appi18n status
appi18n clean
```

### `extract`

Extract `.xcstrings` files from the project to the `i18n/source` directory

```shell
$ appi18n extract ~/path/to/menuist/
```

Index the following `.xcstrings` files

```
menuist
├── Menuist.xcodeproj
├── Menuist
│   ├── InfoPlist.xcstrings
│   ├── Localizable.xcstrings
├── MenuistFinderExtension
│   ├── Info.plist
│   └── Localizable.xcstrings
├── QuickLookPreview
│   ├── Info.plist
│   └── Localizable.xcstrings
└── commons
```

Internationalization files will be extracted to the `i18n/source` directory

```
./i18n
    ├── lproj
    └── source
        └── menuist
            ├── Menuist
            │   ├── InfoPlist.xcstrings
            │   ├── Localizable.xcstrings
            ├── MenuistFinderExtension
            │   ├── Info.plist
            │   └── Localizable.xcstrings
            └── QuickLookPreview
                ├── Info.plist
                └── Localizable.xcstrings
```

### `to-lproj` 

1. If the corresponding .strings file does not exist, it will be created automatically
2. Existing key-value pairs will not be overwritten
3. If a key's value is empty, the default value will be filled in for reference

```shell
$ appi18n to-lproj
```

### `langs`

List existing languages for an app:

```shell
$ appi18n langs menuist
```

Add a new language to one or more apps:

```shell
$ appi18n langs menuist,scap fr
```

List all system-provided language/region identifiers:

```shell
$ appi18n langs --all
```

### `to-xcstrings`

Update `.lproj` to `.xcstrings` (for importing to Xcode)

1. Extract values from `.strings` and import into `.xcstrings`
2. If a key already exists in `.xcstrings` and the value in `.strings` differs from the `.xcstrings` default value, overwrite it with the `.strings` value
3. Skip rules:
   - If a value in `.strings` is the same as the default value in `.xcstrings`, skip update
   - If a value in `.strings` is empty, skip import
   - If the corresponding `.xcstrings` file is missing, skip that `.strings` file and warn

```shell
$ appi18n to-xcstrings
```
