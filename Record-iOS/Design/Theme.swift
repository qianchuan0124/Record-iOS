import SwiftUI
import UIKit

enum Theme {
    static let brand = Color(light: 0x6C5DD3, dark: 0x9B8CFF)
    static let brandDark = Color(light: 0x5648B3, dark: 0xC4BAFF)
    static let brandSoft = Color(light: 0xEFECFB, dark: 0x2A2440)
    static let background = Color(light: 0xF4F5F7, dark: 0x0F1115)
    static let surface = Color(light: 0xFFFFFF, dark: 0x171A21)
    static let surfaceElevated = Color(light: 0xFFFFFF, dark: 0x1E222B)
    static let subtle = Color(light: 0xF7F8FB, dark: 0x1B1F27)
    static let track = Color(light: 0xF0F1F5, dark: 0x242832)
    static let barMuted = Color(light: 0xE4E6EC, dark: 0x2A2F3A)
    static let keypadBackground = Color(light: 0xEFF0F4, dark: 0x11141A)
    static let keypadFunction = Color(light: 0xE3E5EA, dark: 0x2A2F3A)
    static let text = Color(light: 0x1B1F27, dark: 0xF2F4F8)
    static let text2 = Color(light: 0x5A6274, dark: 0xA6ADBB)
    static let text3 = Color(light: 0x8A90A0, dark: 0x6F7787)
    static let expense = Color(light: 0xE2434F, dark: 0xFF6B76)
    static let income = Color(light: 0x18A472, dark: 0x3FD39A)
    static let warning = Color(light: 0xC58A00, dark: 0xFFC15C)
    static let border = Color(light: 0xEBECF0, dark: 0x2A2F3A)
    static let chevron = Color(light: 0xC3C7D0, dark: 0x5A6274)
    static let brandBorder = Color(light: 0xD8D1F6, dark: 0x4A4070)
    static let selectionBorder = Color(light: 0x6C5DD3, dark: 0x3F3A5C)
    static let summaryFill = Color(light: 0xFBF9FF, dark: 0x1C1830)
    static let summaryBorder = Color(light: 0xE7E2FB, dark: 0x2F2848)
    static let salaryTag = Color(light: 0x3B6FE0, dark: 0x8FB2FF)
    static let salaryTagBg = Color(light: 0xEBF1FE, dark: 0x1E2A44)
    static let bonusTag = Color(light: 0xB4690E, dark: 0xFFC15C)
    static let bonusTagBg = Color(light: 0xFEF3E2, dark: 0x3A2B17)
    static let radius: CGFloat = 16

    static let brandGradient = LinearGradient(
        colors: [Color(light: 0x7E6FE6, dark: 0x8B7BF0), Color(light: 0x5B4BC4, dark: 0x6C5DD3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let summaryGradient = LinearGradient(
        colors: [Color(light: 0xF6F3FF, dark: 0x1F1A33), Color(light: 0xFCFBFF, dark: 0x171A21)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum AppFont {
    static let important = Font.system(size: 16, weight: .semibold)
    static let importantRegular = Font.system(size: 16)
    static let secondary = Font.system(size: 14)
    static let secondaryMedium = Font.system(size: 14, weight: .medium)
    static let small = Font.system(size: 13)
    static let smallMedium = Font.system(size: 13, weight: .medium)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        self.init(hex: UInt32(cleaned, radix: 16) ?? 0x94A3B8)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
