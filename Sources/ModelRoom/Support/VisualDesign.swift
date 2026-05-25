import AppKit
import SwiftUI

enum GlassDepth {
    case subtle
    case regular
    case elevated

    var material: Material {
        switch self {
        case .subtle:
            .ultraThinMaterial
        case .regular:
            .thinMaterial
        case .elevated:
            .regularMaterial
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .subtle:
            0.02
        case .regular:
            0.035
        case .elevated:
            0.055
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .subtle:
            4
        case .regular:
            7
        case .elevated:
            10
        }
    }

    var materialOpacity: Double {
        switch self {
        case .subtle:
            0.66
        case .regular:
            0.72
        case .elevated:
            0.78
        }
    }
}

extension View {
    func glassSurface(
        depth: GlassDepth = .regular,
        cornerRadius: CGFloat = 14,
        isActive: Bool = false
    ) -> some View {
        modifier(GlassSurfaceModifier(depth: depth, cornerRadius: cornerRadius, isActive: isActive))
    }

    func glassRowBackground(
        isActive: Bool,
        isSelected: Bool = false,
        cornerRadius: CGFloat = 9
    ) -> some View {
        modifier(GlassRowBackgroundModifier(isActive: isActive, isSelected: isSelected, cornerRadius: cornerRadius))
    }

    func lightweightGlassSurface(
        cornerRadius: CGFloat = 14,
        isActive: Bool = false
    ) -> some View {
        modifier(LightweightGlassSurfaceModifier(cornerRadius: cornerRadius, isActive: isActive))
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    var depth: GlassDepth
    var cornerRadius: CGFloat
    var isActive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(depth.material)
                    .opacity(depth.materialOpacity)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(isActive ? 0.46 : 0.30),
                            .white.opacity(0.08),
                            .black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(isActive ? depth.shadowOpacity + 0.02 : depth.shadowOpacity),
                radius: isActive ? depth.shadowRadius + 2 : depth.shadowRadius,
                x: 0,
                y: isActive ? 6 : 3
            )
    }
}

private struct GlassRowBackgroundModifier: ViewModifier {
    var isActive: Bool
    var isSelected: Bool
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                if isActive {
                    shape
                        .fill(.ultraThinMaterial)
                        .opacity(isSelected ? 0.62 : 0.36)
                }
            }
            .overlay {
                if isActive {
                    shape.strokeBorder(.white.opacity(isSelected ? 0.50 : 0.30), lineWidth: 1)
                }
            }
            .shadow(
                color: .black.opacity(isSelected ? 0.055 : 0.02),
                radius: isSelected ? 6 : 2,
                x: 0,
                y: isSelected ? 3 : 1
            )
            .overlay {
                if isSelected {
                    shape
                        .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
                }
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isActive)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
    }
}

private struct LightweightGlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isActive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .opacity(isActive ? 0.72 : 0.58)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(isActive ? 0.32 : 0.22),
                            .white.opacity(0.06),
                            .black.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(isActive ? 0.035 : 0.018), radius: isActive ? 4 : 2, x: 0, y: 1)
    }
}

struct GlassBackdrop: View {
    var animates = false
    @State private var phase = false

    var body: some View {
        let activePhase = animates && phase

        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(activePhase ? 0.12 : 0.04),
                    Color.green.opacity(activePhase ? 0.03 : 0.08),
                    Color.cyan.opacity(activePhase ? 0.07 : 0.02)
                ],
                startPoint: activePhase ? .topLeading : .bottomLeading,
                endPoint: activePhase ? .bottomTrailing : .topTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.30)
        }
        .onAppear {
            guard animates else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                phase.toggle()
            }
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(isProminent ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isProminent ? .white : .primary.opacity(isEnabled ? 1 : 0.48))
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(0.68)
                if isProminent {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.65 : 0.82) : 0.28))
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(isEnabled ? (isProminent ? 0.28 : 0.20) : 0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isProminent ? 0.07 : 0.03), radius: 5, x: 0, y: 3)
            .opacity(isEnabled ? 1 : 0.62)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

struct GlassSwitchToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                if configuration.isOn {
                    Spacer(minLength: 0)
                }

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)

                if !configuration.isOn {
                    Spacer(minLength: 0)
                }
            }
            .padding(2)
            .frame(width: 42, height: 22)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(configuration.isOn ? 0.30 : (isEnabled ? 0.84 : 0.45))
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isOn ? 0.92 : 0.06))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(configuration.isOn ? 0.42 : 0.18), lineWidth: 1)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

extension AnswerStatus {
    var accentColor: Color {
        switch self {
        case .waiting:
            .secondary
        case .running:
            .blue
        case .finished:
            .green
        case .failed:
            .red
        }
    }
}
