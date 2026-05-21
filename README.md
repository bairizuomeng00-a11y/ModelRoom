# ModelRoom

ModelRoom is a native macOS app for asking one question to multiple AI models at the same time. You can configure OpenAI-compatible and Anthropic Messages-compatible providers, enable or disable saved models, and compare their answers in one conversation window.

ModelRoom 是一个原生 macOS 应用：你可以自由配置多个大模型接口，在一个问题发出后让多个模型同时回答，并在同一屏幕里对比结果。

## Features

- Native SwiftUI macOS interface with a Liquid Glass-inspired design
- OpenAI-compatible Chat Completions API support
- Anthropic Messages-compatible API support
- Per-provider local configuration files
- Enable or disable saved model providers independently
- Chinese and English interface modes
- Conversation history with nested folders and drag-and-drop organization
- Markdown-style rendering for code blocks, tables, and math-style formulas
- DMG packaging script for local distribution

## Privacy

ModelRoom stores runtime configuration on your Mac, not in the app bundle.

- Provider configs are stored under `~/Library/Application Support/ModelRoom/Providers/`.
- API keys are stored as plaintext in local provider config files by design.
- Chat and folder metadata are stored in local app preferences.
- The packaged DMG only contains the app bundle and does not include your local chats or API keys.

Do not commit files from `~/Library/Application Support/ModelRoom` or local preference files.

## Requirements

- macOS 13 or later
- Swift 6 toolchain

## Build

```bash
swift build
```

## Run Locally

```bash
./script/build_and_run.sh
```

## Package DMG

```bash
./script/package_dmg.sh
```

The generated installer will be written to:

```text
dist/ModelRoom.dmg
```

## License

MIT

