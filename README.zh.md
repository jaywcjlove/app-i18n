App i18n
===

轻量级命令行工具，统一管理和优化多 App 的国际化（i18n）流程。

## 核心功能

- 双向转换：`.strings` ⇄ `.lproj` 目录
- 结构化 `.lproj` 特别适合 AI 批量翻译
- 支持统一管理多个 App 的本地化文件
- CLI 优先，易脚本化集成 CI/CD

## .xcstrings vs .lproj

| 特性               | .xcstrings (String Catalogs)          | .lproj (传统结构)                  |
|--------------------|---------------------------------------|-------------------------------------|
| Xcode 体验         | 极佳（自动提取、翻译状态可视化、missing 标记） | 一般（需手动维护）                  |
| Git 冲突           | 高（单文件、多人编辑易冲突）          | 极低（语言独立文件，几乎无冲突）    |
| 多人/外包翻译      | 不友好                                | 非常友好（单语言独立提交）          |
| AI 批量翻译        | 一般                                  | 优秀（结构清晰、易拆分喂 AI）       |
| Apple 推荐         | 强烈（Xcode 15+ 未来标准）            | 仍兼容底层实现                      |

## 为什么选择 appi18n？

- 🔁 `.strings` ↔ `.lproj` 双向无缝转换
- 🤖 `.lproj` 结构最适合喂给 AI 自动翻译
- 📦 多 App 统一管理
- ⚡ 纯 CLI，轻量高效
- 🛠 减少翻译遗漏 & Git 冲突

安装：`brew install jaywcjlove/tap/appi18n` （待发布）  
文档 & 示例：https://github.com/jaywcjlove/appi18n