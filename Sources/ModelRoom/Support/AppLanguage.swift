import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    func text(_ key: AppText) -> String {
        switch (self, key) {
        case (.english, .newChat): "New Chat"
        case (.simplifiedChinese, .newChat): "新建聊天"
        case (.english, .newFolder): "New Folder"
        case (.simplifiedChinese, .newFolder): "新建文件夹"
        case (.english, .deleteChat): "Delete Chat"
        case (.simplifiedChinese, .deleteChat): "删除聊天"
        case (.english, .deleteFolder): "Delete Folder"
        case (.simplifiedChinese, .deleteFolder): "删除文件夹"
        case (.english, .settings): "Settings"
        case (.simplifiedChinese, .settings): "设置"
        case (.english, .toggleSidebar): "Toggle Sidebar"
        case (.simplifiedChinese, .toggleSidebar): "显示/隐藏侧栏"
        case (.english, .settingsMenu): "Settings..."
        case (.simplifiedChinese, .settingsMenu): "设置..."
        case (.english, .chats): "Chats"
        case (.simplifiedChinese, .chats): "聊天"
        case (.english, .folders): "Folders"
        case (.simplifiedChinese, .folders): "文件夹"
        case (.english, .archive): "Archive"
        case (.simplifiedChinese, .archive): "归档"
        case (.english, .activeChats): "Active Chats"
        case (.simplifiedChinese, .activeChats): "当前聊天"
        case (.english, .archivedChats): "Archived Chats"
        case (.simplifiedChinese, .archivedChats): "已归档聊天"
        case (.english, .models): "Models"
        case (.simplifiedChinese, .models): "模型"
        case (.english, .noAnswersYet): "No answers yet"
        case (.simplifiedChinese, .noAnswersYet): "还没有回答"
        case (.english, .askOnce): "Ask once. Compare every enabled model."
        case (.simplifiedChinese, .askOnce): "问一次，同时比较所有启用的模型。"
        case (.english, .you): "You"
        case (.simplifiedChinese, .you): "你"
        case (.english, .running): "Running"
        case (.simplifiedChinese, .running): "运行中"
        case (.english, .askAll): "Ask All"
        case (.simplifiedChinese, .askAll): "全部提问"
        case (.english, .noProvider): "No Provider"
        case (.simplifiedChinese, .noProvider): "没有模型端点"
        case (.english, .identity): "Identity"
        case (.simplifiedChinese, .identity): "身份"
        case (.english, .name): "Name"
        case (.simplifiedChinese, .name): "名称"
        case (.english, .apiType): "API Type"
        case (.simplifiedChinese, .apiType): "接口类型"
        case (.english, .enabled): "Enabled"
        case (.simplifiedChinese, .enabled): "启用"
        case (.english, .disabled): "Disabled"
        case (.simplifiedChinese, .disabled): "已停用"
        case (.english, .endpoint): "Endpoint"
        case (.simplifiedChinese, .endpoint): "端点"
        case (.english, .baseURL): "Base URL"
        case (.simplifiedChinese, .baseURL): "基础 URL"
        case (.english, .apiPath): "API Path"
        case (.simplifiedChinese, .apiPath): "API 路径"
        case (.english, .model): "Model"
        case (.simplifiedChinese, .model): "模型"
        case (.english, .resetEndpoint): "Reset Endpoint"
        case (.simplifiedChinese, .resetEndpoint): "重置端点"
        case (.english, .credentials): "Credentials"
        case (.simplifiedChinese, .credentials): "凭据"
        case (.english, .apiKey): "API Key"
        case (.simplifiedChinese, .apiKey): "API 密钥"
        case (.english, .authMethod): "Auth Method"
        case (.simplifiedChinese, .authMethod): "鉴权方式"
        case (.english, .configurationWarning): "Configuration Warning"
        case (.simplifiedChinese, .configurationWarning): "配置警告"
        case (.english, .generation): "Generation"
        case (.simplifiedChinese, .generation): "生成参数"
        case (.english, .systemPrompt): "System Prompt"
        case (.simplifiedChinese, .systemPrompt): "系统提示词"
        case (.english, .temperature): "Temperature"
        case (.simplifiedChinese, .temperature): "温度"
        case (.english, .maxTokens): "Max Tokens"
        case (.simplifiedChinese, .maxTokens): "最大 Tokens"
        case (.english, .maxContext): "Max Context"
        case (.simplifiedChinese, .maxContext): "最大上下文"
        case (.english, .add): "Add"
        case (.simplifiedChinese, .add): "添加"
        case (.english, .duplicate): "Duplicate"
        case (.simplifiedChinese, .duplicate): "复制"
        case (.english, .delete): "Delete"
        case (.simplifiedChinese, .delete): "删除"
        case (.english, .modelConfiguration): "Model Configuration"
        case (.simplifiedChinese, .modelConfiguration): "模型配置"
        case (.english, .settingsStorageNote): "Provider settings and API keys are saved in local config files."
        case (.simplifiedChinese, .settingsStorageNote): "模型端点设置和 API 密钥会明文保存到本地配置文件。"
        case (.english, .selectModel): "Select a model"
        case (.simplifiedChinese, .selectModel): "选择一个模型"
        case (.english, .untitled): "Untitled"
        case (.simplifiedChinese, .untitled): "未命名"
        case (.english, .newProvider): "New Provider"
        case (.simplifiedChinese, .newProvider): "新模型端点"
        case (.english, .newChatTitle): "New Chat"
        case (.simplifiedChinese, .newChatTitle): "新聊天"
        case (.english, .language): "Language"
        case (.simplifiedChinese, .language): "语言"
        case (.english, .interface): "Interface"
        case (.simplifiedChinese, .interface): "界面"
        case (.english, .waiting): "Waiting"
        case (.simplifiedChinese, .waiting): "等待中"
        case (.english, .thinking): "Thinking"
        case (.simplifiedChinese, .thinking): "思考中"
        case (.english, .done): "Done"
        case (.simplifiedChinese, .done): "完成"
        case (.english, .error): "Error"
        case (.simplifiedChinese, .error): "错误"
        }
    }

    func modelsReady(_ count: Int) -> String {
        switch self {
        case .english:
            "\(count) models ready"
        case .simplifiedChinese:
            "\(count) 个模型已就绪"
        }
    }

    func enabledModels(_ count: Int) -> String {
        switch self {
        case .english:
            "\(count) enabled models"
        case .simplifiedChinese:
            "\(count) 个模型已启用"
        }
    }

    func modelAnswers(_ count: Int) -> String {
        switch self {
        case .english:
            "\(count) model answers"
        case .simplifiedChinese:
            "\(count) 个模型回答"
        }
    }

    func maxTokens(_ count: Int) -> String {
        "\(text(.maxTokens)): \(count)"
    }

    func status(_ status: AnswerStatus) -> String {
        switch status {
        case .waiting:
            text(.waiting)
        case .running:
            text(.thinking)
        case .finished:
            text(.done)
        case .failed:
            text(.error)
        }
    }
}

enum AppText {
    case newChat
    case newFolder
    case deleteChat
    case deleteFolder
    case settings
    case toggleSidebar
    case settingsMenu
    case chats
    case folders
    case archive
    case activeChats
    case archivedChats
    case models
    case noAnswersYet
    case askOnce
    case you
    case running
    case askAll
    case noProvider
    case identity
    case name
    case apiType
    case enabled
    case disabled
    case endpoint
    case baseURL
    case apiPath
    case model
    case resetEndpoint
    case credentials
    case apiKey
    case authMethod
    case configurationWarning
    case generation
    case systemPrompt
    case temperature
    case maxTokens
    case maxContext
    case add
    case duplicate
    case delete
    case modelConfiguration
    case settingsStorageNote
    case selectModel
    case untitled
    case newProvider
    case newChatTitle
    case language
    case interface
    case waiting
    case thinking
    case done
    case error
}
