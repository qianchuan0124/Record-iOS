import SwiftUI
import UIKit

struct Card<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }
}

struct CategoryBadge: View {
    let icon: String
    let colorHex: String
    var size: CGFloat = 38

    var body: some View {
        let tint = CategoryPalette.color(forIcon: icon) ?? Color(hexString: colorHex)
        Group {
            if let asset = CategoryPalette.assetName(forIcon: icon) {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.52, height: size * 0.52)
                    .foregroundStyle(tint)
            } else {
                Text(icon)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct SubcategoryBadge: View {
    let subcategory: String
    let category: String
    var size: CGFloat = 30

    var body: some View {
        let tint = CategoryPalette.color(category)
        Group {
            if let image = SubcategoryIconCatalog.image(for: subcategory, category: category) {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.58, height: size * 0.58)
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .background(tint.opacity(0.17), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            } else if let symbol = SubcategoryIconCatalog.symbol(for: subcategory, category: category) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .background(tint.opacity(0.17), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            } else {
                CategoryBadge(
                    icon: CategoryPalette.icon(category),
                    colorHex: CategoryPalette.hex(category),
                    size: size
                )
            }
        }
    }
}

struct SwipeBackEnabler: UIViewControllerRepresentable {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigation = controller.navigationController else { return }
            navigation.interactivePopGestureRecognizer?.delegate = context.coordinator
            navigation.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

struct PageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(Theme.text)
    }
}

struct PushedPageHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .padding(.horizontal, 64)

            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text(L10n.Common.close)
                    }
                    .foregroundStyle(Theme.brand)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
                trailing
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .background(Theme.background)
    }
}

struct PushedPageChrome<Trailing: View>: ViewModifier {
    let title: String
    let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                PushedPageHeader(title: title) { trailing }
            }
            .background(SwipeBackEnabler().frame(width: 0, height: 0))
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    func pushedPageChrome(title: String) -> some View {
        modifier(PushedPageChrome(title: title) { EmptyView() })
    }

    func pushedPageChrome<Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(PushedPageChrome(title: title, trailing: trailing))
    }
}

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var date: Date
    @State private var draft: Date

    init(title: String = L10n.Detail.pickDate, date: Binding<Date>) {
        self.title = title
        _date = date
        _draft = State(initialValue: date.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .padding(.horizontal, 64)

                HStack {
                    Button(L10n.Common.close) { dismiss() }
                        .foregroundStyle(Theme.brand)

                    Spacer(minLength: 8)

                    Button(L10n.Common.done) {
                        date = draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.brand)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            DatePicker("", selection: $draft, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .tint(Theme.brand)
                .transaction { $0.animation = nil }
                .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .background(Theme.background)
        .tint(Theme.brand)
        .presentationDetents([.medium])
    }
}

struct DatePickerOverlay: View {
    @Binding var isPresented: Bool
    let title: String
    @Binding var date: Date
    @State private var draft: Date

    init(isPresented: Binding<Bool>, title: String = L10n.Detail.pickDate, date: Binding<Date>) {
        _isPresented = isPresented
        self.title = title
        _date = date
        _draft = State(initialValue: date.wrappedValue)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                ZStack {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .padding(.horizontal, 64)

                    HStack {
                        Button(L10n.Common.close) { isPresented = false }
                            .foregroundStyle(Theme.brand)

                        Spacer(minLength: 8)

                        Button(L10n.Common.done) {
                            date = draft
                            isPresented = false
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.brand)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                DatePicker("", selection: $draft, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .tint(Theme.brand)
                    .transaction { $0.animation = nil }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom))
        }
        .animation(.easeInOut(duration: 0.22), value: isPresented)
    }
}

struct EmptyHint: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundStyle(Theme.text3)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }
}

struct StatColumn: View {
    let title: String
    let value: String
    var color: Color = Theme.text

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.text3)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SummaryCard: View {
    let income: Double
    let expense: Double

    private var balance: Double { income - expense }

    var body: some View {
        HStack(spacing: 0) {
            StatColumn(title: L10n.Summary.expense, value: Money.string(expense), color: Theme.expense)
            Divider().frame(height: 28)
            StatColumn(title: L10n.Summary.income, value: Money.string(income), color: Theme.income)
            Divider().frame(height: 28)
            StatColumn(title: L10n.Summary.balance, value: Money.string(balance))
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.summaryGradient)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.summaryBorder, lineWidth: 1)
        }
    }
}
