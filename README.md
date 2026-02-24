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

```
./i18n
├── lproj
│   ├── menuist
│   │   ├── en.lproj
│   │   │   ├── finder-extension
│   │   │   │   └── Localizable.strings
│   │   │   ├── InfoPlist.strings
│   │   │   ├── Localizable.strings
│   │   │   └── quick-look
│   │   │       └── Localizable.strings
│   │   └── zh-Hans.lproj
│   │       ├── finder-extension
│   │       │   └── Localizable.strings
│   │       ├── InfoPlist.strings
│   │       ├── Localizable.strings
│   │       └── quick-look
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
    │   ├── finder-extension
    │   │   └── Localizable.xcstrings
    │   ├── InfoPlist.xcstrings
    │   ├── Localizable.xcstrings
    │   └── quick-look
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

Show help:

```bash
swift run appi18n --help
```

Extract `.xcstrings` from an Xcode project:

```bash
swift run appi18n extract /path/to/YourApp
```

Convert `.xcstrings` to `.lproj`:

```bash
swift run appi18n to-lproj
```

Update `.xcstrings` from `.lproj`:

```bash
swift run appi18n to-xcstrings
```

Check translation status:

```bash
swift run appi18n status
```

Clean empty/outdated `.lproj` files:

```bash
swift run appi18n clean
```

## App i18n CLI Command Help

```
Usage: appi18n <command> [options]

Commands:
  extract      Extract all .xcstrings from Xcode project to i18n/source
  to-lproj     Convert .xcstrings to .lproj structure (default output to i18n/lproj)
  to-xcstrings Update .lproj to .xcstrings (for importing to Xcode)
  status       Check translation status (missing / incomplete languages)
  clean        Clean outdated/empty .lproj files
  help         Show this help information
```

### `extract`

Extract `.xcstrings` files from the project to the `i18n/source` directory

```shell
$ appi18n extract ~/path/to/menuist/
```

Index the following `.xcstrings` files

```
├── Menuist
│   ├── InfoPlist.xcstrings
│   ├── Localizable.xcstrings
├── Menuist.xcodeproj
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
        ├── menuist
        │   ├── finder-extension
        │   │   └── Localizable.xcstrings
        │   ├── InfoPlist.xcstrings
        │   ├── Localizable.xcstrings
        │   └── quick-look
        │       └── Localizable.xcstrings
```

### `to-lproj` 

1. If the corresponding .strings file does not exist, it will be created automatically
2. Existing key-value pairs will not be overwritten
3. If a key's value is empty, the default value will be filled in for reference

```shell
$ appi18n to-lproj
```

### `to-xcstrings`

Update `.lproj` to `.xcstrings` (for importing to Xcode)

1. Extract values from `.strings` and put them into the `.xcstrings` file
2. Existing key-value pairs in `.xcstrings` will be overwritten by values from `.strings`
3. Empty values in `.strings` will not be updated to the `.xcstrings` file

```shell
$ appi18n to-xcstrings
```
