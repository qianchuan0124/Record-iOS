import SwiftUI

enum CategoryPalette {
    static func hex(_ name: String) -> String {
        switch name {
        case "餐饮": "FF7A45"
        case "交通": "3B82F6"
        case "购物": "EC4899"
        case "居家": "10B981"
        case "人情": "F59E0B"
        case "医疗": "EF4444"
        case "娱乐": "06B6D4"
        case "学习": "8B5CF6"
        case "金融": "14B8A6"
        case "快递": "64748B"
        default: "94A3B8"
        }
    }


    private static let fallbackHexes = [
        "F97316", "0EA5E9", "A855F7", "22C55E", "E11D48",
        "EAB308", "14B8A6", "6366F1", "84CC16", "F43F5E",
        "06B6D4", "8B5CF6", "F59E0B", "10B981", "3B82F6",
        "EC4899", "64748B", "94A3B8", "EF4444", "FF7A45"
    ]

    static func uniqueHexes(for names: [String]) -> [String: String] {
        var used = Set<String>()
        var result: [String: String] = [:]

        for name in names {
            let value = hex(name)
            if value != "94A3B8", !used.contains(value) {
                result[name] = value
                used.insert(value)
            }
        }

        for name in names where result[name] == nil {
            if let available = fallbackHexes.first(where: { !used.contains($0) }) {
                result[name] = available
                used.insert(available)
            } else {
                result[name] = hex(name)
            }
        }

        return result
    }

    static func color(forHex value: String) -> Color {
        switch value {
        case "FF7A45": color("餐饮")
        case "3B82F6": color("交通")
        case "EC4899": color("购物")
        case "10B981": color("居家")
        case "F59E0B": color("人情")
        case "EF4444": color("医疗")
        case "06B6D4": color("娱乐")
        case "8B5CF6": color("学习")
        case "14B8A6": color("金融")
        case "64748B": color("快递")
        default: Color(hexString: value)
        }
    }

    static func color(_ name: String) -> Color {
        switch name {
        case "餐饮": Color(light: 0xFF7A45, dark: 0xFF9A66)
        case "交通": Color(light: 0x3B82F6, dark: 0x6CA6FF)
        case "购物": Color(light: 0xEC4899, dark: 0xFF7AB8)
        case "居家": Color(light: 0x10B981, dark: 0x45D6A8)
        case "人情": Color(light: 0xF59E0B, dark: 0xFFC15C)
        case "医疗": Color(light: 0xEF4444, dark: 0xFF7A7A)
        case "娱乐": Color(light: 0x06B6D4, dark: 0x45D6E6)
        case "学习": Color(light: 0x8B5CF6, dark: 0xA98BFF)
        case "金融": Color(light: 0x14B8A6, dark: 0x3FD6C6)
        case "快递": Color(light: 0x64748B, dark: 0x93A1B5)
        default: Color(light: 0x94A3B8, dark: 0x8C97A8)
        }
    }

    static func assetName(forIcon icon: String) -> String? {
        switch icon {
        case "餐": "CategoryFood"
        case "交": "CategoryTraffic"
        case "购": "CategoryShopping"
        case "居": "CategoryHome"
        case "人": "CategoryRelationship"
        case "医": "CategoryMedical"
        case "娱": "CategoryEntertainment"
        case "学": "CategoryStudy"
        case "金": "CategoryFinance"
        case "递": "CategoryExpress"
        case "其": "CategoryOther"
        default: nil
        }
    }

    static func color(forIcon icon: String) -> Color? {
        switch icon {
        case "餐": color("餐饮")
        case "交": color("交通")
        case "购": color("购物")
        case "居": color("居家")
        case "人": color("人情")
        case "医": color("医疗")
        case "娱": color("娱乐")
        case "学": color("学习")
        case "金": color("金融")
        case "递": color("快递")
        case "其": color("其他")
        default: nil
        }
    }

    static func icon(_ name: String) -> String {
        switch name {
        case "餐饮": "餐"
        case "交通": "交"
        case "购物": "购"
        case "居家": "居"
        case "人情": "人"
        case "医疗": "医"
        case "娱乐": "娱"
        case "学习": "学"
        case "金融": "金"
        case "快递": "递"
        default: "其"
        }
    }
}
