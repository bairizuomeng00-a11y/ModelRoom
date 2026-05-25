import Foundation

enum ProviderEndpointPolicy {
    static func normalized(_ provider: ProviderConfig) -> ProviderConfig {
        var adjusted = provider
        adjusted.baseURL = adjusted.baseURL.trimmed
        adjusted.endpointPath = adjusted.endpointPath.trimmed
        adjusted.model = adjusted.model.trimmed
        adjusted.apiKey = adjusted.apiKey.trimmed

        applyKnownProviderDefaults(&adjusted)
        inferKindFromEndpoint(&adjusted)
        repairDefaultEndpointMismatch(&adjusted)

        if adjusted.endpointPath.isEmpty {
            adjusted.endpointPath = adjusted.kind.defaultPath
        }

        return adjusted
    }

    static func endpointURL(for provider: ProviderConfig) -> URL? {
        let provider = normalized(provider)
        let base = provider.baseURL.trimmed
        let path = provider.endpointPath.trimmed
        guard !base.isEmpty, !path.isEmpty else { return nil }

        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }

        let normalizedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        return URL(string: normalizedBase + normalizedPath)
    }

    static func configurationProblem(for provider: ProviderConfig) -> String? {
        let provider = normalized(provider)
        guard let url = endpointURL(for: provider) else {
            return "Invalid endpoint URL."
        }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        switch provider.kind {
        case .anthropicMessages:
            if host == "api.openai.com" {
                return "Anthropic Messages cannot use api.openai.com. Set the provider Base URL to its Anthropic-compatible endpoint."
            }
            if path.contains("/chat/completions") {
                return "Anthropic Messages must use a messages endpoint, usually /v1/messages."
            }
            if provider.thinkingMode.isEnabled && provider.maxTokens <= 1024 {
                return "Anthropic thinking mode requires Max Context to be greater than 1024."
            }
        case .openAICompatible:
            if path.contains("/messages") || provider.baseURL.lowercased().contains("/anthropic") {
                return "OpenAI Compatible cannot use an Anthropic messages endpoint. Change API Type to Anthropic Messages."
            }
        }

        return nil
    }

    private static func inferKindFromEndpoint(_ provider: inout ProviderConfig) {
        let base = provider.baseURL.lowercased()
        let path = provider.endpointPath.lowercased()

        if base.contains("/anthropic") || path.contains("/messages") {
            provider.kind = .anthropicMessages
        }
    }

    private static func repairDefaultEndpointMismatch(_ provider: inout ProviderConfig) {
        switch provider.kind {
        case .anthropicMessages:
            if provider.endpointPath.isEmpty ||
                provider.endpointPath == APIKind.openAICompatible.defaultPath {
                provider.endpointPath = APIKind.anthropicMessages.defaultPath
            }

            if provider.baseURL.isEmpty ||
                provider.baseURL == APIKind.openAICompatible.defaultBaseURL {
                provider.baseURL = APIKind.anthropicMessages.defaultBaseURL
            }
        case .openAICompatible:
            if provider.endpointPath.isEmpty ||
                provider.endpointPath == APIKind.anthropicMessages.defaultPath {
                provider.endpointPath = APIKind.openAICompatible.defaultPath
            }
        }
    }

    private static func applyKnownProviderDefaults(_ provider: inout ProviderConfig) {
        let signature = "\(provider.name) \(provider.model) \(provider.baseURL)".lowercased()
        let needsRepair = provider.baseURL.isEmpty ||
            provider.baseURL == APIKind.openAICompatible.defaultBaseURL ||
            provider.endpointPath.isEmpty ||
            provider.endpointPath == APIKind.openAICompatible.defaultPath

        guard needsRepair else { return }

        if signature.contains("deepseek") {
            provider.kind = .anthropicMessages
            provider.baseURL = "https://api.deepseek.com/anthropic"
            provider.endpointPath = APIKind.anthropicMessages.defaultPath
        } else if signature.contains("minimax") {
            provider.kind = .anthropicMessages
            provider.baseURL = "https://api.minimaxi.com/anthropic"
            provider.endpointPath = APIKind.anthropicMessages.defaultPath
        } else if signature.contains("claude") || signature.contains("anthropic") {
            provider.kind = .anthropicMessages
            provider.baseURL = APIKind.anthropicMessages.defaultBaseURL
            provider.endpointPath = APIKind.anthropicMessages.defaultPath
        }
    }
}
