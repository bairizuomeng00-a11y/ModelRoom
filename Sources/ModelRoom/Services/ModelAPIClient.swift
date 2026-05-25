import Foundation

struct ModelReply {
    var text: String
    var thinking: String?
    var reasoningTokenCount: Int?
}

struct ChatRequestMessage: Sendable {
    var role: String
    var content: String
}

enum ModelAPIError: LocalizedError {
    case invalidURL
    case emptyKey
    case invalidConfiguration(String, RequestDebugInfo)
    case http(Int, String, RequestDebugInfo)
    case missingContent

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .emptyKey:
            "Missing API key"
        case let .invalidConfiguration(message, debugInfo):
            "\(message)\n\n\(debugInfo.description)"
        case let .http(code, body, debugInfo):
            "HTTP \(code): \(body)\n\n\(debugInfo.description)"
        case .missingContent:
            "No text content returned"
        }
    }
}

struct RequestDebugInfo: Sendable {
    var url: String
    var apiType: String
    var authMethod: String

    var description: String {
        "Request: \(apiType), \(authMethod), \(url)"
    }
}

struct ModelAPIClient {
    func send(prompt: String, provider: ProviderConfig) async throws -> ModelReply {
        try await send(messages: [ChatRequestMessage(role: "user", content: prompt)], provider: provider)
    }

    func send(messages: [ChatRequestMessage], provider: ProviderConfig) async throws -> ModelReply {
        let provider = ProviderEndpointPolicy.normalized(provider)
        guard !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelAPIError.emptyKey
        }
        if let problem = ProviderEndpointPolicy.configurationProblem(for: provider) {
            throw ModelAPIError.invalidConfiguration(problem, debugInfo(for: provider))
        }

        switch provider.kind {
        case .openAICompatible:
            return try await sendOpenAICompatible(messages: messages, provider: provider)
        case .anthropicMessages:
            return try await sendAnthropicMessages(messages: messages, provider: provider)
        }
    }

    private func sendOpenAICompatible(messages: [ChatRequestMessage], provider: ProviderConfig) async throws -> ModelReply {
        var requestMessages: [[String: String]] = []
        if !provider.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requestMessages.append(["role": "system", "content": provider.systemPrompt])
        }
        requestMessages.append(contentsOf: messages.map { ["role": $0.role, "content": $0.content] })

        let body = OpenAIRequest(
            model: provider.model,
            messages: requestMessages,
            temperature: provider.temperature,
            max_tokens: provider.maxTokens,
            reasoning_effort: provider.thinkingMode.openAIReasoningEffort
        )

        var request = try makeRequest(provider: provider)
        applyAuthHeaders(to: &request, provider: provider, defaultMethod: .bearer)
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await perform(request, provider: provider)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = response.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelAPIError.missingContent
        }
        return ModelReply(
            text: content,
            thinking: nil,
            reasoningTokenCount: response.usage?.completion_tokens_details?.reasoning_tokens
        )
    }

    private func sendAnthropicMessages(messages: [ChatRequestMessage], provider: ProviderConfig) async throws -> ModelReply {
        let body = AnthropicRequest(
            model: provider.model,
            max_tokens: provider.maxTokens,
            temperature: provider.thinkingMode.isEnabled ? nil : provider.temperature,
            thinking: provider.thinkingMode.anthropicBudgetTokens(maxTokens: provider.maxTokens).map {
                AnthropicThinking(type: "enabled", budget_tokens: $0)
            },
            system: provider.systemPrompt.isEmpty ? nil : provider.systemPrompt,
            messages: normalizedAnthropicMessages(messages)
        )

        var request = try makeRequest(provider: provider)
        applyAuthHeaders(to: &request, provider: provider, defaultMethod: .xAPIKey)
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await perform(request, provider: provider)
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = response.content.compactMap { $0.text }.joined(separator: "\n\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelAPIError.missingContent
        }
        let thinking = response.content.compactMap(\.thinkingText).joined(separator: "\n\n")
        return ModelReply(
            text: text,
            thinking: thinking.isEmpty ? nil : thinking,
            reasoningTokenCount: nil
        )
    }

    private func normalizedAnthropicMessages(_ messages: [ChatRequestMessage]) -> [AnthropicMessage] {
        var result: [AnthropicMessage] = []

        for message in messages {
            let role = message.role == "assistant" ? "assistant" : "user"
            let content = message.content.trimmed
            guard !content.isEmpty else { continue }

            if let last = result.last, last.role == role {
                result[result.count - 1] = AnthropicMessage(
                    role: role,
                    content: "\(last.content)\n\n\(content)"
                )
            } else {
                result.append(AnthropicMessage(role: role, content: content))
            }
        }

        if result.isEmpty {
            return [AnthropicMessage(role: "user", content: "")]
        }
        return result
    }

    private func makeRequest(provider: ProviderConfig) throws -> URLRequest {
        guard let url = ProviderEndpointPolicy.endpointURL(for: provider) else {
            throw ModelAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func applyAuthHeaders(to request: inout URLRequest, provider: ProviderConfig, defaultMethod: APIAuthMethod) {
        let key = provider.apiKey.trimmed
        let method = provider.authMethod == .automatic ? defaultMethod : provider.authMethod

        switch method {
        case .automatic:
            break
        case .bearer:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .xAPIKey:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }

        if provider.kind == .anthropicMessages && provider.authMethod == .automatic {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }
    }

    private func perform(_ request: URLRequest, provider: ProviderConfig) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return data
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ModelAPIError.http(http.statusCode, body.prefix(700).description, debugInfo(for: request, provider: provider))
        }
        return data
    }

    private func debugInfo(for request: URLRequest, provider: ProviderConfig) -> RequestDebugInfo {
        RequestDebugInfo(
            url: request.url?.absoluteString ?? "unknown URL",
            apiType: provider.kind.displayName(language: .english),
            authMethod: provider.authMethod.displayName(language: .english)
        )
    }

    private func debugInfo(for provider: ProviderConfig) -> RequestDebugInfo {
        RequestDebugInfo(
            url: ProviderEndpointPolicy.endpointURL(for: provider)?.absoluteString ?? "unknown URL",
            apiType: provider.kind.displayName(language: .english),
            authMethod: provider.authMethod.displayName(language: .english)
        )
    }
}

private struct OpenAIRequest: Encodable {
    var model: String
    var messages: [[String: String]]
    var temperature: Double
    var max_tokens: Int
    var reasoning_effort: String?
}

private struct OpenAIResponse: Decodable {
    var choices: [Choice]
    var usage: Usage?

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String?
    }

    struct Usage: Decodable {
        var completion_tokens_details: CompletionTokensDetails?
    }

    struct CompletionTokensDetails: Decodable {
        var reasoning_tokens: Int?
    }
}

private struct AnthropicRequest: Encodable {
    var model: String
    var max_tokens: Int
    var temperature: Double?
    var thinking: AnthropicThinking?
    var system: String?
    var messages: [AnthropicMessage]
}

private struct AnthropicThinking: Encodable {
    var type: String
    var budget_tokens: Int
}

private struct AnthropicMessage: Encodable {
    var role: String
    var content: String
}

private struct AnthropicResponse: Decodable {
    var content: [ContentBlock]

    struct ContentBlock: Decodable {
        var type: String
        var text: String?
        var thinking: String?
        var data: String?

        var thinkingText: String? {
            switch type {
            case "thinking":
                return thinking?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? thinking : nil
            case "redacted_thinking":
                return data?.isEmpty == false ? "Provider returned a redacted thinking block." : nil
            default:
                return nil
            }
        }
    }
}
