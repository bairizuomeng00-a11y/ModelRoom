import SwiftUI

struct ConversationView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            GlassBackdrop()

            GeometryReader { proxy in
                let composerHeight = proxy.size.height * 0.25
                let transcriptHeight = max(0, proxy.size.height - composerHeight - 1)

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if model.selectedTurns.isEmpty {
                                EmptyAnswersView(language: model.language)
                                    .frame(maxWidth: .infinity, minHeight: max(220, transcriptHeight * 0.55))
                            } else {
                                ForEach(model.selectedTurns) { turn in
                                    QuestionCard(prompt: turn.prompt, language: model.language)

                                    ForEach(turn.answers) { answer in
                                        AnswerCard(answer: answer, language: model.language)
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(height: transcriptHeight)

                    Divider()
                        .opacity(0.35)

                    ComposerView()
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        .frame(height: composerHeight)
                        .background {
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .opacity(0.34)
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.18)
                        }
                        .overlay(alignment: .top) {
                            Divider()
                                .opacity(0.42)
                        }
                }
            }
        }
    }
}

private struct EmptyAnswersView: View {
    var language: AppLanguage
    @State private var breathes = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.85))
                .scaleEffect(breathes ? 1.04 : 0.98)
                .opacity(breathes ? 0.92 : 0.68)

            Text(language.text(.askOnce))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .glassSurface(depth: .subtle, cornerRadius: 18)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breathes = true
            }
        }
    }
}

private struct QuestionCard: View {
    var prompt: String
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.text(.you))
                .font(.system(size: 16.5, weight: .semibold))
            RenderedMessageView(content: prompt)
        }
        .padding(12)
        .lightweightGlassSurface(cornerRadius: 12)
    }
}

private struct AnswerCard: View {
    var answer: ModelAnswer
    var language: AppLanguage
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(answer.providerName)
                    .font(.system(size: 16.5, weight: .semibold))
                    .lineLimit(1)

                Text(answer.modelName)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                StatusBadge(status: answer.status, elapsedText: answer.elapsedText, language: language)
            }

            switch answer.status {
            case .running, .waiting:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(language.text(.thinking))
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                }
            case let .failed(message):
                Text(message)
                    .font(.system(size: 15.5))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            case .finished:
                RenderedMessageView(content: answer.content)
            }
        }
        .padding(12)
        .lightweightGlassSurface(cornerRadius: 12, isActive: isHovering || answer.status == .running)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(answer.status.accentColor.opacity(0.72))
                .frame(width: 3)
                .padding(.vertical, 14)
        }
        .animation(.easeInOut(duration: 0.18), value: answer.status)
        .onHover { isHovering = $0 }
    }
}

private struct StatusBadge: View {
    var status: AnswerStatus
    var elapsedText: String
    var language: AppLanguage

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(status: status)
            Text(elapsedText.isEmpty ? language.status(status) : "\(language.status(status)) \(elapsedText)")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusDot: View {
    var status: AnswerStatus
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay {
                if status == .running {
                    Circle()
                        .stroke(color.opacity(0.35), lineWidth: 1)
                        .scaleEffect(pulse ? 2.4 : 1)
                        .opacity(pulse ? 0 : 0.85)
                }
            }
            .onAppear {
                guard status == .running else { return }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
            .onChange(of: status) { newStatus in
                pulse = false
                guard newStatus == .running else { return }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
    }

    private var color: Color {
        status.accentColor
    }
}
