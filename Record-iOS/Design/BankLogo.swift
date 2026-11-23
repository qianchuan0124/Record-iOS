import SwiftUI
#if canImport(UIKit)
import UIKit

enum BankName {
    static func display(_ name: String) -> String {
        if name == "中国邮政储蓄银行" { return "邮储银行" }
        guard name.hasPrefix("中国"), name.count > 4 else { return name }
        return String(name.dropFirst(2))
    }

    static func short(_ name: String) -> String {
        if name == "中国银行" { return "中国" }
        var value = name
        if value.hasPrefix("中国") { value.removeFirst(2) }
        value = value.replacingOccurrences(of: "银行", with: "")
        if value == "邮政储蓄" { return "邮储" }
        return value.isEmpty ? String(name.prefix(2)) : String(value.prefix(2))
    }
}

enum BankLogoCatalog {
    struct Preset: Decodable {
        let icon: String
        let name: String
        let keywords: [String]
    }

    private static let presets: [Preset] = {
        let urls = [
            Bundle.main.url(forResource: "bank-logo-presets", withExtension: "json"),
            Bundle.main.url(forResource: "bank-logo-presets", withExtension: "json", subdirectory: "Resources")
        ].compactMap { $0 }
        for url in urls {
            if let data = try? Data(contentsOf: url),
               let items = try? JSONDecoder().decode([Preset].self, from: data) {
                return items
            }
        }
        return []
    }()

    private static var imageCache: [String: UIImage] = [:]
    private static var nameCache: [String: Preset] = [:]

    static var allPresets: [Preset] { presets }

    static func preset(icon: String, name: String) -> Preset? {
        if !icon.isEmpty, icon.count > 2, let found = presets.first(where: { $0.icon == icon }) {
            return found
        }

        let key = name.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        if let cached = nameCache[key] { return cached }

        if let exact = presets.first(where: { $0.name == key }) {
            nameCache[key] = exact
            return exact
        }

        if let matched = presets.first(where: { preset in
            preset.keywords.contains { $0.count >= 2 && key.contains($0) }
        }) {
            nameCache[key] = matched
            return matched
        }
        return nil
    }

    static func image(iconID: String) -> UIImage? {
        if let cached = imageCache[iconID] { return cached }
        let candidates = [
            Bundle.main.url(forResource: iconID, withExtension: "png", subdirectory: "BankIcons"),
            Bundle.main.url(forResource: iconID, withExtension: "png")
        ]
        for url in candidates {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                imageCache[iconID] = image
                return image
            }
        }
        return nil
    }
}

struct BankLogo: View {
    let name: String
    var icon: String = ""
    var colorHex: String = "1B7F79"
    var size: CGFloat = 34

    private var preset: BankLogoCatalog.Preset? {
        BankLogoCatalog.preset(icon: icon, name: name)
    }

    private var logoImage: UIImage? {
        guard let preset else { return nil }
        return BankLogoCatalog.image(iconID: preset.icon)
    }

    var body: some View {
        Group {
            if let logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
                    .frame(width: size, height: size)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }
            } else if !icon.isEmpty, icon.count <= 2 {
                Text(icon)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color(hexString: colorHex), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            } else {
                Image(systemName: "building.columns")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Theme.text3)
                    .frame(width: size, height: size)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}
#endif
