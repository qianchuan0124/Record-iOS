import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
#endif

struct Toast: Identifiable {
    enum Style {
        case success
        case error
    }

    let id = UUID()
    let message: String
    let style: Style
}

@MainActor
@Observable
final class ToastCenter {
    var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, style: Toast.Style = .success) {
        dismissTask?.cancel()
        let item = Toast(message: message, style: style)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            current = item
        }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(style == .error ? .error : .success)
        #endif
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard current?.id == item.id else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                current = nil
            }
        }
    }
}

struct ToastHost: View {
    var topInset: CGFloat = 6
    @Environment(ToastCenter.self) private var center

    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: toast.style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(toast.style == .success ? Theme.income : Theme.expense)
                    Text(toast.message)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, topInset)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: center.current?.id)
        .allowsHitTesting(false)
    }
}
