App i18n
===

Lightweight CLI tool for unifying and optimizing the internationalization (i18n) workflow across multiple apps.

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

## Installation (Coming Soon)

```bash
brew install jaywcjlove/tap/appi18n
```