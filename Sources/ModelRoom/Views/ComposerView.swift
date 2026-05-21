import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPromptFocused = false

    var body: some View {
        GeometryReader { proxy in
            let controlsHeight: CGFloat = 38
            let controlsGap: CGFloat = 8
            let bottomBreathing: CGFloat = 12
            let promptHeight = max(54, proxy.size.height - controlsHeight - controlsGap - bottomBreathing)

            VStack(alignment: .leading, spacing: controlsGap) {
                ZStack(alignment: .topLeading) {
                    PromptTextView(text: $model.prompt, isFocused: $isPromptFocused)
                        .frame(height: promptHeight)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    if model.prompt.isEmpty {
                        Text(model.language.text(.askOnce))
                            .font(.system(size: 15.5))
                            .foregroundStyle(.secondary.opacity(0.70))
                            .allowsHitTesting(false)
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                    }
                }
                .glassSurface(depth: .subtle, cornerRadius: 12, isActive: isPromptFocused)

                HStack {
                    Text(model.language.enabledModels(model.runnableProviders.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        model.submitPrompt()
                    } label: {
                        Label(model.isRunning ? model.language.text(.running) : model.language.text(.askAll), systemImage: "paperplane")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(GlassButtonStyle(isProminent: true))
                    .disabled(model.prompt.trimmed.isEmpty || model.runnableProviders.isEmpty || model.isRunning)
                }
                .frame(height: controlsHeight)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .opacity(0.20)
                }
                .animation(.easeInOut(duration: 0.18), value: model.isRunning)
            }
        }
    }
}
