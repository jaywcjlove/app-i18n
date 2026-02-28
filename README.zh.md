[English](./README.md)

App i18n
===

轻量级命令行工具，用于统一管理和优化多个 App 的国际化（i18n）流程。当前项目也包含[我的应用](https://wangchujiang.com/#/app)国际化文件存放在 [`i18n`](./i18n/source/) 目录中。

`appi18n` 帮助你在 `.xcstrings` 与 `.lproj` 之间进行双向转换，使本地化文件更适合多人 Git 协作与 AI 批量翻译，同时保持与 Xcode 的无缝集成。

## 为什么需要它？

在多人协作与 AI 参与翻译的场景下，`.xcstrings` 存在一些实际问题：

* 单文件结构，容易产生 Git 冲突
* 多语言集中在同一个文件中，不利于拆分翻译任务
* 文件体积较大，批量喂给 AI 时容易消耗过多 token，甚至导致翻译中断

`appi18n` 将 `.xcstrings` 拆分为结构清晰的 `.lproj` 目录，便于维护与协作；
同时也支持再转换回 `.xcstrings`，确保与 Xcode 工作流无缝衔接，享受 Xcode 自动提取 + 翻译状态可视化。


## 核心能力

* 🔁 双向转换：`.xcstrings` ⇄ `.lproj`
* 🤖 `.lproj` 结构更适合 AI 批量翻译
* 👥 便于多人 Git 协作维护
* 📦 支持统一管理多个 App 的本地化文件
* ⚡ CLI 优先，易于脚本化与 CI/CD 集成

## `.xcstrings` vs `.lproj`

| 特性       | `.xcstrings`     | `.lproj`   |
| -------- | ---------------- | ---------- |
| Xcode 体验 | 极佳（自动提取、翻译状态可视化） | 一般（需手动维护）  |
| Git 冲突   | 高（单文件易冲突）        | 极低（语言独立文件） |
| 多人协作     | 不友好              | 非常友好       |
| AI 批量翻译  | 一般               | 优秀         |
| Apple 推荐 | 强烈推荐（Xcode 15+）  | 兼容底层实现     |

## appi18n 带来的价值

* 减少 Git 冲突
* 降低翻译遗漏
* 提高 AI 翻译效率
* 让国际化成为一个可重复、可自动化的流程

## MyApp i18n

我的应用国际化文件都存储在 [`i18n/source`](./i18n/source/) 目录中，大家协同维护 [`i18n/lproj`](./i18n/lproj/) 的语言文件，将通过 `appi18n` 命令合并到 [`i18n/source`](./i18n/source/) 中

```shell
./i18n
├── lproj # 国际化语言维护
│   ├── menuist # 应用 menuist
│   │   ├── ...
│   └── scap    # 应用 scap
│       ├── en.lproj
│       │   ├── Localizable.strings
│       │   └── InfoPlist.strings
│       └── zh-Hans.lproj
│           ├── Localizable.strings
│           └── InfoPlist.strings
└── source # 国际化源文件
    ├── menuist # 应用 menuist
    │   ├── ...
    └── scap    # 应用 scap
        ├── InfoPlist.xcstrings
        └── Localizable.xcstrings
```

下面展示将新应用的国际化文件添加到当前仓库维护的示例命令，包含导入文件和新增语言等操作。

```bash
# 1️⃣ 提取 .xcstrings 国际化文件
$ appi18n extract  ~/git/IconedApp/Iconed
# 2️⃣ 将 .xcstrings 转换成 .lproj 用于维护
$ appi18n to-lproj
# 3️⃣ 为 Iconed 应用添加 fr 语言
$ appi18n langs iconed fr
# 4️⃣ 将所有 .lproj 内容更新到 .xcstrings 文件中
$ appi18n to-xcstrings
# 5️⃣ 语言与默认语言一致，也要更新
$ appi18n to-xcstrings --no-skip-default-value
# ✅ 💯 用更新后的文件替换 Xcode 中的 .xcstrings 文件
```

## 安装

```bash
brew install jaywcjlove/tap/appi18n
```

## App i18n CLI 命令帮助

```shell
Usage: appi18n <command> [options]

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

Commands:
  extract      从 Xcode 项目中提取所有 .xcstrings 到 i18n/source
  to-lproj     将 .xcstrings 转换为 .lproj 结构 (默认输出到 i18n/lproj)
  langs        查看应用语言或为应用添加语言
  to-xcstrings 将 .lproj 更新到 .xcstrings (用于导入 Xcode)中
  status       检查翻译状态 (missing / incomplete 语言)
  clean        清理过时/空 .lproj 文件
  help         显示此帮助信息
```

示例：

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

从项目中提取 `.xcstrings` 到 `i18n/source` 目录中

```shell
$ appi18n extract ~/path/to/menuist/
```

索引到下面 `.xcstrings` 文件

```bash
menuist # menuist app
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

国际化文件将被提取到 `i18n/source` 目录中

```bash
./i18n
    ├── lproj
    └── source
        └── menuist # menuist app
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

1. 若对应的 .strings 文件不存在，则自动创建
2. 已存在的键值不会被覆盖
3. 若某个键的值为空，则填入默认值以供参考

```shell
$ appi18n to-lproj
```

### `langs`

查看某个应用已有语言：

```shell
$ appi18n langs menuist
```

为一个或多个应用添加新语言：

```shell
$ appi18n langs menuist,scap fr
```

列出系统提供的全部语言/区域标识：

```shell
$ appi18n langs --all
```

### `to-xcstrings`

将 `.lproj` 更新到 `.xcstrings` (用于导入 Xcode)中

1. **提取导入**：将 `.strings` 文件中的键值对提取并导入到 `.xcstrings` 文件中
2. **覆盖规则**：若 `.xcstrings` 中已存在相同键，且 `.strings` 中的值与 `.xcstrings` 默认值不同，则用 `.strings` 的值覆盖
3. **跳过规则**：
   - 若 `.strings` 中的值与 `.xcstrings` 默认值相同，则跳过更新(`--no-skip-default-value` 控制不跳过)
   - 若 `.strings` 中的值为空，则跳过导入
   - 若未找到对应的 `.xcstrings` 文件，则跳过该 `.strings` 文件并提示

```shell
$ appi18n to-xcstrings
# 强制不跳过更新，当前语言与默认语言一致
$ appi18n to-xcstrings --no-skip-default-value
```

### `clean`

清理空/过时的国际化文件，保持源文件与本地化文件的同步

1. **清理空文件夹**：删除空的 `.lproj` 目录和文件
2. **同步删除内容**：当 `.xcstrings` 中某些键被移除时，对应在 `.lproj` 文件中的相同键也会被清理
3. **清理过时文件**：移除不再使用的 `.strings` 文件
4. **保持一致性**：确保 `.xcstrings` 和 `.lproj` 之间的内容保持同步

```shell
$ appi18n clean
```

## 开发

### 构建

需要 Swift 5.9+。

```bash
swift build -c release
# 可执行文件位置：
# .build/release/appi18n
```

### 测试 / 命令试用

```bash
# 查看帮助：
swift run appi18n --help
# 从 Xcode 项目提取 `.xcstrings`：
swift run appi18n extract /path/to/YourApp
# 将 `.xcstrings` 转换为 `.lproj`：
swift run appi18n to-lproj
# 将 `.lproj` 更新回 `.xcstrings`：
swift run appi18n to-xcstrings
# 强制不跳过更新，当前语言与默认语言一致
swift run appi18n to-xcstrings --no-skip-default-value
# 为一个或多个应用添加新语言：
swift run appi18n langs menuist,scap fr
# 查看某个应用已有语言：
swift run appi18n langs menuist
# 列出可用的推荐语言代码：
swift run appi18n langs 
# 列出系统提供的全部语言/区域标识：
swift run appi18n langs --all
# 检查翻译状态：
swift run appi18n status
# 清理空/过时 `.lproj` 文件：
swift run appi18n clean
```

### 发布命令

```shell
$ env 'CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache' swift build -c release
$ tar -czf ./appi18n.tar.gz -C ./.build/arm64-apple-macosx/release appi18n
```

## 许可证

基于 MIT 许可证授权。