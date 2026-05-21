import SwiftUI

struct ProviderEditorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let provider = bindingForSelectedProvider {
                ProviderForm(provider: provider)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text(model.language.text(.noProvider))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .background(.bar)
    }

    private var bindingForSelectedProvider: Binding<ProviderConfig>? {
        guard let id = model.selectedProviderID,
              let index = model.providers.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return Binding {
            model.providers[index]
        } set: { newValue in
            model.updateProvider(newValue)
        }
    }
}

struct ProviderForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding var provider: ProviderConfig

    var body: some View {
        Form {
            Section(model.language.text(.identity)) {
                TextField(model.language.text(.name), text: $provider.name)

                Picker(model.language.text(.apiType), selection: $provider.kind) {
                    ForEach(APIKind.allCases) { kind in
                        Text(kind.displayName(language: model.language)).tag(kind)
                    }
                }
                .onChange(of: provider.kind) { newKind in
                    provider.baseURL = newKind.defaultBaseURL
                    provider.endpointPath = newKind.defaultPath
                    if provider.model.trimmed.isEmpty {
                        provider.model = newKind == .openAICompatible ? "gpt-4.1" : "claude-sonnet-4-5"
                    }
                }

                Toggle(model.language.text(.enabled), isOn: $provider.isEnabled)
            }

            Section(model.language.text(.endpoint)) {
                TextField(model.language.text(.baseURL), text: $provider.baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField(model.language.text(.apiPath), text: $provider.endpointPath)
                    .textFieldStyle(.roundedBorder)
                TextField(model.language.text(.model), text: $provider.model)
                    .textFieldStyle(.roundedBorder)

                Button {
                    model.resetEndpointForSelectedProvider()
                } label: {
                    Label(model.language.text(.resetEndpoint), systemImage: "arrow.counterclockwise")
                }
            }

            Section(model.language.text(.credentials)) {
                TextField(model.language.text(.apiKey), text: $provider.apiKey)
                    .textFieldStyle(.roundedBorder)

                Picker(model.language.text(.authMethod), selection: $provider.authMethod) {
                    ForEach(APIAuthMethod.allCases) { method in
                        Text(method.displayName(language: model.language)).tag(method)
                    }
                }
            }

            if let warning = ProviderEndpointPolicy.configurationProblem(for: provider) {
                Section(model.language.text(.configurationWarning)) {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Section(model.language.text(.generation)) {
                TextField(model.language.text(.systemPrompt), text: $provider.systemPrompt, axis: .vertical)
                    .lineLimit(3...6)

                VStack(alignment: .leading) {
                    HStack {
                        Text(model.language.text(.temperature))
                        Spacer()
                        Text(provider.temperature, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $provider.temperature, in: 0...2, step: 0.05)
                }

                HStack {
                    Text(model.language.text(.maxContext))
                    Spacer()
                    TextField(
                        model.language.text(.maxContext),
                        value: $provider.maxTokens,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                }

                Stepper(model.language.maxTokens(provider.maxTokens), value: $provider.maxTokens, in: 1...1_000_000, step: 1024)
            }
        }
        .formStyle(.grouped)
    }
}
