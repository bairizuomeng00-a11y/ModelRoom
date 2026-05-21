import Foundation

struct ProviderConfig: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var kind: APIKind
    var baseURL: String
    var endpointPath: String
    var model: String
    var authMethod: APIAuthMethod
    var apiKey: String
    var systemPrompt: String
    var temperature: Double
    var maxTokens: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: APIKind,
        baseURL: String? = nil,
        endpointPath: String? = nil,
        model: String,
        authMethod: APIAuthMethod = .automatic,
        apiKey: String = "",
        systemPrompt: String = "",
        temperature: Double = 0.7,
        maxTokens: Int = 1200,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseURL = baseURL ?? kind.defaultBaseURL
        self.endpointPath = endpointPath ?? kind.defaultPath
        self.model = model
        self.authMethod = authMethod
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.isEnabled = isEnabled
    }

    var isRunnable: Bool {
        isEnabled &&
            !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !endpointPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct StoredProviderConfig: Identifiable, Codable {
    var id: UUID
    var name: String
    var kind: APIKind
    var baseURL: String
    var endpointPath: String
    var model: String
    var authMethod: APIAuthMethod?
    var apiKey: String?
    var systemPrompt: String
    var temperature: Double
    var maxTokens: Int
    var isEnabled: Bool

    init(_ provider: ProviderConfig) {
        id = provider.id
        name = provider.name
        kind = provider.kind
        baseURL = provider.baseURL
        endpointPath = provider.endpointPath
        model = provider.model
        authMethod = provider.authMethod
        apiKey = provider.apiKey
        systemPrompt = provider.systemPrompt
        temperature = provider.temperature
        maxTokens = provider.maxTokens
        isEnabled = provider.isEnabled
    }

    func hydrated(apiKey externalAPIKey: String) -> ProviderConfig {
        ProviderConfig(
            id: id,
            name: name,
            kind: kind,
            baseURL: baseURL,
            endpointPath: endpointPath,
            model: model,
            authMethod: authMethod ?? .automatic,
            apiKey: apiKey?.isEmpty == false ? apiKey ?? "" : externalAPIKey,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens,
            isEnabled: isEnabled
        )
    }
}
