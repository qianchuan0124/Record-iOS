import SwiftUI
#if canImport(UIKit)
import UIKit

struct TopSegmentedControl<Item: Hashable>: UIViewRepresentable {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item
    var height: CGFloat = 40

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: items.map(title))
        control.selectedSegmentIndex = items.firstIndex(of: selection) ?? 0
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)

        control.selectedSegmentTintColor = UIColor(Theme.surface)
        control.backgroundColor = UIColor(Theme.track)
        control.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor(Theme.text2)
        ], for: .normal)
        control.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor(Theme.text)
        ], for: .selected)
        control.layer.cornerRadius = 10
        control.layer.masksToBounds = true
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        if let index = items.firstIndex(of: selection), control.selectedSegmentIndex != index {
            control.selectedSegmentIndex = index
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width, height: height)
    }

    final class Coordinator: NSObject {
        var parent: TopSegmentedControl

        init(_ parent: TopSegmentedControl) {
            self.parent = parent
        }

        @objc func changed(_ sender: UISegmentedControl) {
            let index = sender.selectedSegmentIndex
            guard parent.items.indices.contains(index) else { return }
            parent.selection = parent.items[index]
        }
    }
}
#endif
