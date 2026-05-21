# ModelRoom

ModelRoom is a native macOS app for asking one question to multiple AI models at the same time. You can configure OpenAI-compatible and Anthropic Messages-compatible providers, enable or disable saved models, and compare their answers in one conversation window.

## 中文介绍

ModelRoom 是一个原生 macOS 多模型聊天应用。它可以让你自由配置多个大模型服务商和模型接口，在同一个问题发出后，让多个 AI 模型同时思考并回答，方便你在一个窗口里横向对比不同模型的观点、速度和表达风格。

你可以在设置里添加 OpenAI 兼容接口或 Anthropic Messages 兼容接口，分别保存每个模型商的接口地址、模型名、API Key、认证方式和上下文长度。每个模型配置都可以单独启用或停用，聊天记录也可以用文件夹归档、拖动整理和嵌套管理。

这个项目适合想在 Mac 上统一管理多个 AI 模型、对比模型回答、测试第三方兼容接口，或者搭建个人多模型工作台的用户。

## Features

- Native SwiftUI macOS interface with a Liquid Glass-inspired design
- OpenAI-compatible Chat Completions and Anthropic Messages-compatible API support
- Per-provider local configuration files
- Enable or disable saved model providers independently
- Chinese and English interface modes
- Conversation history with nested folders and drag-and-drop organization
- Markdown-style rendering for code blocks, tables, and math-style formulas


## Privacy

ModelRoom stores runtime configuration on your Mac, not in the app bundle.

- Provider configs are stored under `~/Library/Application Support/ModelRoom/Providers/`.
- Chat and folder metadata are stored in local app preferences.



## Requirements

- macOS 13 or later
- Swift 6 toolchain


## License

MIT
