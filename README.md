[中文](./README.zh.md)

App i18n
===

Lightweight CLI tool for unifying and optimizing the internationalization (i18n) workflow across multiple apps. This project also contains [my app](https://wangchujiang.com/#/app) internationalization files stored in the [`i18n`](./i18n/source/) directory.

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

[iconed](./i18n/lproj/iconed) • [keyzer](./i18n/lproj/keyzer/) • [menuist](./i18n/lproj/menuist/) • [scap](./i18n/lproj/scap/)

My app internationalization files are stored in the [`i18n/source`](./i18n/source/) directory. Teams collaborate to maintain the [`i18n/lproj`](./i18n/lproj/) language files, which will be merged into [`i18n/source`](./i18n/source/) using the `appi18n` command.

```shell
./i18n
├── lproj # Internationalization language maintenance
│   ├── menuist # menuist app
│   │   ├── ...
│   └── scap   # scap app
│       ├── en.lproj
│       │   ├── Localizable.strings
│       │   └── InfoPlist.strings
│       └── zh-Hans.lproj
│           ├── Localizable.strings
│           └── InfoPlist.strings
└── source # Internationalization source files
    ├── menuist # menuist app
    │   ├── ...
    └── scap   # scap app
        ├── InfoPlist.xcstrings
        └── Localizable.xcstrings
```

The following shows example commands for adding internationalization files of a new app to the current repository's maintenance, including operations like importing files and adding new languages.

```bash
# 1️⃣ Extract .xcstrings localization file
$ appi18n extract  ~/git/IconedApp/Iconed
# 2️⃣ Convert .xcstrings to .lproj for maintenance
$ appi18n to-lproj
# 3️⃣ Add French (fr) language to Iconed app
$ appi18n langs iconed fr
# 4️⃣ Update all .lproj content back to .xcstrings
$ appi18n to-xcstrings
# 5️⃣ Also update when language matches base language
$ appi18n to-xcstrings --no-skip-default-value
# ✅ 💯 Replace .xcstrings files in Xcode with the updated ones
```

## Installation

```bash
brew install jaywcjlove/tap/appi18n
```

## App i18n CLI Command Help

```shell
Usage: appi18n <command> [options]

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

Commands:
  extract      Extract all .xcstrings from Xcode project to i18n/source
  to-lproj     Convert .xcstrings to .lproj structure (default output to i18n/lproj)
  langs        List languages for app(s) or add a language to app(s)
  to-xcstrings Update .lproj to .xcstrings (for importing to Xcode)
  status       Check translation status (missing / incomplete languages)
  preview      Generate an HTML preview for translations
  ghpage       Commit generated HTML files to a branch (default: gh-pages)
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
appi18n preview
appi18n ghpage
appi18n clean
```

### `extract`

Extract `.xcstrings` files from the project to the `i18n/source` directory

```shell
$ appi18n extract ~/path/to/menuist/
```

Index the following `.xcstrings` files

```bash
menuist # menuist 应用
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

```shell
./i18n
    ├── lproj
    └── source
        └── menuist  # menuist 应用
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

List commonly used languages

```shell
$ appi18n langs

# Arabic (ar)                            Japanese (ja)
# Bulgarian (bg)                         Korean (ko)
# Catalan (ca)                           Lithuanian (lt)
# Czech (cs)                             Latvian (lv)
# Danish (da)                            Malay (ms)
# German (de)                            Norwegian Bokmål (nb)
# Greek (el)                             Dutch (nl)
# English (en)                           Polish (pl)
# English (Australia) (en-AU)            Portuguese (pt)
# English (Canada) (en-CA)               Portuguese (Brazil) (pt-BR)
# English (United Kingdom) (en-GB)       Portuguese (Portugal) (pt-PT)
# English (United States) (en-US)        Romanian (ro)
# Spanish (es)                           Russian (ru)
# Spanish (Latin America) (es-419)       Slovak (sk)
# Estonian (et)                          Slovenian (sl)
# Finnish (fi)                           Serbian (sr)
# French (fr)                            Serbian (Latin) (sr-Latn)
# French (Canada) (fr-CA)                Swedish (sv)
# Hebrew (he)                            Thai (th)
# Hindi (hi)                             Turkish (tr)
# Croatian (hr)                          Ukrainian (uk)
# Hungarian (hu)                         Vietnamese (vi)
# Indonesian (id)                        Chinese, Simplified (zh-Hans)
# Italian (it)                           Chinese, Traditional (zh-Hant)
```

### `to-xcstrings`

Update `.lproj` to `.xcstrings` (for importing to Xcode)

1. Extract values from `.strings` and import into `.xcstrings`
2. If a key already exists in `.xcstrings` and the value in `.strings` differs from the `.xcstrings` default value, overwrite it with the `.strings` value
3. Skip rules:
   - If a value in `.strings` is the same as the default value in `.xcstrings`, skip update (`--no-skip-default-value`)
   - If a value in `.strings` is empty, skip import
   - If the corresponding `.xcstrings` file is missing, skip that `.strings` file and warn

```shell
$ appi18n to-xcstrings
# Force not skipping updates, the current language is the same as the default language.
$ appi18n to-xcstrings --no-skip-default-value
```

### `preview`

Generate HTML localization preview pages (`index.html` + per-app detail pages).

Parameters:

1. `apps` (optional): comma-separated app names under `i18n/lproj`, e.g. `menuist,scap`
2. `-o, --output` (optional): output directory, default `.html`

```shell
# Preview all apps, output to ./.html
$ appi18n preview

# Preview one app
$ appi18n preview menuist

# Preview multiple apps
$ appi18n preview menuist,scap

# Custom output directory
$ appi18n preview -o i18n/preview-site
# or
$ appi18n preview menuist -o i18n/preview-menuist
```

### `ghpage`

Commit generated HTML files from a source folder to a target branch using `git worktree`.

Parameters:

1. `-b, --branch` (optional): target branch, default `gh-pages`
2. `-s, --source` (optional): source folder, default `.html`
3. `--message` (optional): custom commit message

```shell
# Commit ./.html to gh-pages
$ appi18n ghpage

# Commit from custom folder to gh-pages
$ appi18n ghpage -s i18n/preview-site

# Commit to a custom branch
$ appi18n ghpage -b pages

# Custom branch + source + commit message
$ appi18n ghpage -b pages -s i18n/preview-site --message "chore: update preview site"
```

### `clean`

Clean up empty/outdated internationalization files and keep source files synchronized with localization files

1. **Clean empty folders**: Remove empty `.lproj` directories and files
2. **Synchronized deletion**: When certain keys are removed from `.xcstrings`, corresponding keys in `.lproj` files will also be cleaned up
3. **Remove outdated files**: Delete unused `.strings` files
4. **Maintain consistency**: Ensure content synchronization between `.xcstrings` and `.lproj`

```shell
$ appi18n clean
```

## Development

### Build

Requires Swift 5.9+.

```bash
swift build -c release
# The executable will be at:
# .build/release/appi18n
```

### Test / Try Commands

```bash
# Show help:
swift run appi18n --help
# Extract `.xcstrings` from an Xcode project:
swift run appi18n extract /path/to/YourApp
# Convert `.xcstrings` to `.lproj`:
swift run appi18n to-lproj
# Update `.xcstrings` from `.lproj`:
swift run appi18n to-xcstrings
# Force not skipping updates, the current language is the same as the default language.
swift run appi18n to-xcstrings --no-skip-default-value
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
# Generate i18n HTML preview:
swift run appi18n preview
# Generate preview for selected apps:
swift run appi18n preview menuist,scap
# Generate preview to a custom directory:
swift run appi18n preview -o i18n/preview-site
# Commit generated HTML to gh-pages:
swift run appi18n ghpage
# Commit generated HTML from custom dir/branch:
swift run appi18n ghpage -b pages -s i18n/preview-site
# Clean empty/outdated `.lproj` files:
swift run appi18n clean
```

### Release command

```shell
$ env 'CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache' swift build -c release
$ tar -czf ./appi18n.tar.gz -C ./.build/arm64-apple-macosx/release appi18n
$ cd $(brew --repository jaywcjlove/tap)
```

## License

Licensed under the MIT License.
