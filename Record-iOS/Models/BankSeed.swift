import Foundation
import SwiftData

enum BankSeed {
    static let entries: [(name: String, icon: String, colorHex: String)] = [
        ("招商银行", "招", "D7261E"),
        ("建设银行", "建", "0066B3"),
        ("中国工商银行", "工", "C8102E"),
        ("中国农业银行", "农", "00703C"),
        ("中国银行", "中", "00529C"),
        ("交通银行", "交", "004B8D"),
        ("中国邮政储蓄银行", "邮", "E60012"),
        ("浦发银行", "浦", "005BAC"),
        ("中信银行", "信", "CF142B"),
        ("中国光大银行", "光", "E8112D"),
        ("中国民生银行", "民", "004F9F"),
        ("宁波银行", "宁", "1B7F79")
    ]

    @MainActor
    static func seedIfNeeded(_ context: ModelContext, existing: [Bank]) {
        guard existing.isEmpty else { return }
        for (index, preset) in builtInPresets.enumerated() {
            context.insert(Bank(
                name: preset.name,
                icon: preset.icon,
                colorHex: preset.colorHex,
                order: index,
                isSystem: true
            ))
        }
        try? context.save()
    }

    static func isDefaultBank(name: String) -> Bool {
        builtInPresets.contains { $0.name == name }
    }

    private static var builtInPresets: [(name: String, icon: String, colorHex: String)] {
        if !BankLogoCatalog.allPresets.isEmpty {
            return BankLogoCatalog.allPresets.map { ($0.name, $0.icon, "1B7F79") }
        }
        if !entries.isEmpty {
            return entries
        }
        let urls = [
            Bundle.main.url(forResource: "bank-presets", withExtension: "json"),
            Bundle.main.url(forResource: "bank-presets", withExtension: "json", subdirectory: "Resources")
        ].compactMap { $0 }

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let map = try? JSONDecoder().decode([String: String].self, from: data),
                  !map.isEmpty else { continue }
            return map.values
                .sorted()
                .map { ($0, BankName.short($0), "1B7F79") }
        }
        return []
    }

    @MainActor
    static func repairDefaultBanksIfNeeded(_ context: ModelContext, existing: [Bank]) {
        let key = "record.bankCatalog.defaultsRepaired.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        var names = Set(existing.map(\.name))
        for bank in existing where !bank.isSystem && isDefaultBank(name: bank.name) {
            bank.isSystem = true
        }

        var order = existing.map(\.order).max() ?? -1
        for preset in builtInPresets where !names.contains(preset.name) {
            order += 1
            context.insert(Bank(
                name: preset.name,
                icon: preset.icon,
                colorHex: preset.colorHex,
                order: order,
                isSystem: true
            ))
            names.insert(preset.name)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    @MainActor
    static func seedFullCatalogIfNeeded(_ context: ModelContext, existing: [Bank]) {
        let key = "record.bankCatalog.seeded.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let presets = builtInPresets
        guard !presets.isEmpty else { return }

        let existingNames = Set(existing.map(\.name))
        let existingIcons = Set(existing.compactMap { bank in
            BankLogoCatalog.preset(icon: bank.icon, name: bank.name)?.icon
        })
        var order = existing.map(\.order).max() ?? -1

        for preset in presets {
            guard !existingNames.contains(preset.name), !existingIcons.contains(preset.icon) else { continue }
            order += 1
            context.insert(Bank(name: preset.name, icon: preset.icon, colorHex: preset.colorHex, order: order, isSystem: true))
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
