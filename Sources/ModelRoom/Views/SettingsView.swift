import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            GlassBackdrop()

            HSplitView {
                VStack(spacing: 0) {
                    List {
                        Section(model.language.text(.models)) {
                            ForEach(model.providers) { provider in
                                SettingsProviderRow(
                                    provider: provider,
                                    language: model.language,
                                    isSelected: model.selectedProviderID == provider.id,
                                    isEnabled: Binding {
                                        provider.isEnabled
                                    } set: { newValue in
                                        model.setProviderEnabled(newValue, providerID: provider.id)
                                    }
                                )
                                .onTapGesture {
                                    model.selectedProviderID = provider.id
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)

                    HStack {
                        SettingsIconButton(
                            systemImage: "plus",
                            help: model.language.text(.add)
                        ) {
                            model.addProvider()
                        }

                        SettingsIconButton(
                            systemImage: "plus.square.on.square",
                            help: model.language.text(.duplicate),
                            isDisabled: model.selectedProvider == nil
                        ) {
                            model.duplicateSelectedProvider()
                        }

                        SettingsIconButton(
                            systemImage: "trash",
                            help: model.language.text(.delete),
                            role: .destructive,
                            isDisabled: model.selectedProvider == nil
                        ) {
                            model.deleteSelectedProvider()
                        }

                        Spacer()
                    }
                    .padding(12)
                    .glassSurface(depth: .subtle, cornerRadius: 0)
                }
                .frame(minWidth: 240, idealWidth: 270, maxWidth: 330)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(model.language.text(.language))
                            .font(.headline)
                        Picker(model.language.text(.language), selection: $model.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                    Divider()
                        .opacity(0.35)

                    if let provider = bindingForSelectedProvider {
                        VStack(alignment: .leading, spacing: 12) {

                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(model.language.text(.modelConfiguration))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(model.language.text(.settingsStorageNote))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            ProviderForm(provider: provider)
                                .id(provider.wrappedValue.id)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text(model.language.text(.selectModel))
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .glassSurface(depth: .subtle, cornerRadius: 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 560)
            }
        }
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

private struct SettingsIconButton: View {
    var systemImage: String
    var help: String
    var role: ButtonRole?
    var isDisabled = false
    var action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(role: role) {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.55) : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHovering && !isDisabled ? 0.10 : 0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(isHovering && !isDisabled ? 0.20 : 0.08), lineWidth: 1)
        }
        .scaleEffect(isHovering && !isDisabled ? 1.04 : 1)
        .opacity(isDisabled ? 0.55 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: isHovering)
        .onHover { isHovering = $0 }
        .help(help)
        .disabled(isDisabled)
    }
}

private struct SettingsProviderRow: View {
    var provider: ProviderConfig
    var language: AppLanguage
    var isSelected: Bool
    @Binding var isEnabled: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: provider.isEnabled ? "cpu" : "pause.circle")
                .foregroundStyle(iconColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name.isEmpty ? language.text(.untitled) : provider.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)

                Text(provider.model.isEmpty ? provider.kind.displayName(language: language) : provider.model)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.68) : Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle(language.text(.enabled), isOn: $isEnabled)
                .toggleStyle(GlassSwitchToggleStyle())
                .labelsHidden()
                .help(isEnabled ? language.text(.enabled) : language.text(.disabled))
        }
        .padding(.leading, isSelected ? 12 : 7)
        .padding(.trailing, isSelected ? 10 : 7)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassRowBackground(isActive: isSelected || isHovering, isSelected: isSelected)
        .listRowBackground(Color.clear)
        .scaleEffect(isHovering ? 1.005 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .onHover { isHovering = $0 }
    }

    private var iconColor: Color {
        if isSelected {
            return .primary
        }
        return provider.isRunnable ? .green : .secondary
    }
}
