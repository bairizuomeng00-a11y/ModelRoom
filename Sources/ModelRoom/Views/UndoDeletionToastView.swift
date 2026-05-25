import SwiftUI

struct UndoDeletionToastView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let deletion = model.pendingUndoDeletion {
            HStack(spacing: 10) {
                Image(systemName: deletion.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background {
                        Circle()
                            .fill(.thinMaterial)
                            .opacity(0.76)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    }

                Text(deletion.message)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Button {
                    model.undoPendingDeletion()
                } label: {
                    Text(model.language.text(.undo))
                }
                .buttonStyle(GlassButtonStyle(isProminent: true))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassSurface(depth: .elevated, cornerRadius: 18, isActive: true)
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
