import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

struct SyncDataCounts: Equatable {
    var records: Int
    var deposits: Int
    var payroll: Int
    var budgets: Int

    var text: String {
        L10n.Sync.backupCounts(records, deposits, payroll, budgets)
    }
}

struct SyncBackupInfo: Identifiable {
    let url: URL
    let createdAt: Date
    let deviceName: String
    let isDesktop: Bool
    let records: Int
    let deposits: Int
    let payroll: Int
    let budgets: Int
    let byteSize: Int

    var id: URL { url }

    var counts: SyncDataCounts {
        SyncDataCounts(records: records, deposits: deposits, payroll: payroll, budgets: budgets)
    }

    var countsText: String { counts.text }

    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: createdAt)
    }

    var sizeText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteSize))
    }
}

enum SyncFolderService {
    static let folderBookmarkKey = "record.sync.folderBookmark"
    static let folderNameKey = "record.sync.folderName"
    static let autoBackupKey = "record.sync.autoBackup"
    static let lastBackupAtKey = "record.sync.lastBackupAt"
    static let lastBackupTextKey = "record.sync.lastBackupText"

    private static let prefix = "record-backup-"

    private static var bookmarkFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("record-sync-folder.bookmark")
    }

    private static func loadBookmark() -> Data? {
        if let data = try? Data(contentsOf: bookmarkFileURL) { return data }
        return UserDefaults.standard.data(forKey: folderBookmarkKey)
    }

    private static var heldFolder: URL?
    private static var holdingAccess = false

    private static func releaseHeldFolder() {
        if holdingAccess {
            heldFolder?.stopAccessingSecurityScopedResource()
        }
        heldFolder = nil
        holdingAccess = false
    }

    private static func storeBookmark(_ data: Data) {
        try? FileManager.default.createDirectory(at: bookmarkFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: bookmarkFileURL, options: .atomic)
        UserDefaults.standard.set(data, forKey: folderBookmarkKey)
    }

    static func saveFolder(_ url: URL) throws {
        let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        releaseHeldFolder()
        storeBookmark(data)
        UserDefaults.standard.set(url.lastPathComponent, forKey: folderNameKey)
    }

    static func clearFolder() {
        releaseHeldFolder()
        try? FileManager.default.removeItem(at: bookmarkFileURL)
        UserDefaults.standard.removeObject(forKey: folderBookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderNameKey)
    }

    static func resolveFolder() -> URL? {
        if let heldFolder { return heldFolder }
        guard let data = loadBookmark() else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            clearFolder()
            return nil
        }

        let accessing = url.startAccessingSecurityScopedResource()
        if accessing {
            if let refreshed = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
                storeBookmark(refreshed)
            }
            heldFolder = url
            holdingAccess = true
        } else if stale {
            clearFolder()
            return nil
        } else {
            heldFolder = url
        }
        return url
    }

    static func displayName(for url: URL) -> String {
        if url.pathExtension.lowercased() == "db" {
            return "\(L10n.Sync.desktopBadge) · \(desktopDateText(url))"
        }
        let name = url.deletingPathExtension().lastPathComponent
        return name.replacingOccurrences(of: "record-backup-", with: "")
    }

    private static func desktopDateText(_ url: URL) -> String {
        let parts = url.deletingPathExtension().lastPathComponent.split(separator: "_")
        guard parts.count >= 3 else { return url.deletingPathExtension().lastPathComponent }
        let stamp = String(parts[1]) + String(parts[2])
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyyMMddHHmmss"
        guard let date = parser.date(from: stamp) else { return url.deletingPathExtension().lastPathComponent }
        let display = DateFormatter()
        display.locale = Locale(identifier: "zh_CN")
        display.dateFormat = "M月d日 HH:mm"
        return display.string(from: date)
    }

    @discardableResult
    static func writeBackup(context: ModelContext) throws -> URL {
        guard let folder = resolveFolder() else {
            throw SyncError.noFolder
        }

        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

        let data = try SyncSnapshot.makeData(context: context)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = folder.appendingPathComponent("\(prefix)\(formatter.string(from: Date())).json")
        try data.write(to: url, options: .atomic)

        let display = DateFormatter()
        display.locale = Locale(identifier: "zh_CN")
        display.dateFormat = "M月d日 HH:mm"
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackupAtKey)
        UserDefaults.standard.set(display.string(from: Date()), forKey: lastBackupTextKey)

        prune(in: folder)
        return url
    }

    static func listBackups() -> [URL] {
        (try? loadBackups()) ?? []
    }

    static func backupInfo(for url: URL) -> SyncBackupInfo {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fallbackDate = values?.contentModificationDate ?? .distantPast
        let size = values?.fileSize ?? 0

        if url.pathExtension.lowercased() == "db" {
            let info = DesktopSnapshot.info(for: url)
            return SyncBackupInfo(
                url: url,
                createdAt: fallbackDate,
                deviceName: L10n.Sync.desktopSource,
                isDesktop: true,
                records: info?.records ?? 0,
                deposits: info?.deposits ?? 0,
                payroll: (info?.salaries ?? 0) + (info?.bonuses ?? 0),
                budgets: info?.budgets ?? 0,
                byteSize: size
            )
        }

        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SyncBackupInfo(
                url: url,
                createdAt: fallbackDate,
                deviceName: L10n.Sync.iosSource,
                isDesktop: false,
                records: 0,
                deposits: 0,
                payroll: 0,
                budgets: 0,
                byteSize: size
            )
        }

        let device = (object["device"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? L10n.Sync.iosSource
        let createdAt: Date = {
            if let raw = object["createdAt"] as? String,
               let date = ISO8601DateFormatter().date(from: raw) {
                return date
            }
            return fallbackDate
        }()

        return SyncBackupInfo(
            url: url,
            createdAt: createdAt,
            deviceName: device,
            isDesktop: false,
            records: (object["records"] as? [Any])?.count ?? 0,
            deposits: (object["deposits"] as? [Any])?.count ?? 0,
            payroll: ((object["salaries"] as? [Any])?.count ?? 0) + ((object["bonuses"] as? [Any])?.count ?? 0),
            budgets: (object["budgets"] as? [Any])?.count ?? 0,
            byteSize: size
        )
    }

    static func loadBackups() throws -> [URL] {
        guard let folder = resolveFolder() else { throw SyncError.noFolder }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

        var coordinationError: NSError?
        var listed: [URL] = []
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .withoutChanges, error: &coordinationError) { coordinated in
            var directories = [coordinated]
            let desktopDirectory = coordinated.appendingPathComponent("记账清单", isDirectory: true)
            if FileManager.default.fileExists(atPath: desktopDirectory.path) {
                directories.append(desktopDirectory)
            }

            let rootChildren = (try? FileManager.default.contentsOfDirectory(
                at: coordinated,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )) ?? []
            for child in rootChildren where child.lastPathComponent.hasPrefix("Record备份-") {
                let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDirectory {
                    directories.append(child)
                }
            }

            for directory in directories {
                listed += (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: .skipsHiddenFiles
                )) ?? []
            }
        }
        if coordinationError != nil {
            clearFolder()
            throw SyncError.folderAccessDenied
        }

        return listed
            .filter { url in
                let name = url.lastPathComponent
                let isIOSSnapshot = name.hasPrefix(prefix) && url.pathExtension.lowercased() == "json"
                let isDesktopSnapshot = name.hasPrefix("record_") && url.pathExtension.lowercased() == "db"
                return isIOSSnapshot || isDesktopSnapshot
            }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
    }

    @MainActor
    static func restore(from url: URL, context: ModelContext) throws {
        if url.pathExtension.lowercased() == "db" {
            try DesktopSnapshot.restore(dbURL: url, context: context)
            return
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        try SyncSnapshot.restore(data: data, context: context)
    }

    static func autoBackupIfNeeded(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: autoBackupKey) else { return }
        guard resolveFolder() != nil else { return }
        let last = UserDefaults.standard.double(forKey: lastBackupAtKey)
        guard Date().timeIntervalSince1970 - last > 300 else { return }
        try? writeBackup(context: context)
    }

    private static func prune(in folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        let backups = files
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }

        for url in backups.dropFirst(5) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum SyncError: LocalizedError {
    case noFolder
    case folderAccessDenied
    case invalidDesktopBackup

    var errorDescription: String? {
        switch self {
        case .noFolder: L10n.Sync.noFolder
        case .folderAccessDenied: L10n.Sync.accessLost
        case .invalidDesktopBackup: L10n.Sync.invalidDesktop
        }
    }
}

private enum SyncSnapshot {
    struct Payload: Codable {
        var createdAt: Date
        var device: String
        var hardware: HardwareInfo?
        var records: [RecordDTO]
        var categories: [CategoryDTO]
        var customBanks: [BankDTO]?
        var deposits: [DepositDTO]
        var salaries: [SalaryDTO]
        var bonuses: [BonusDTO]
        var budgets: [BudgetDTO]
        var budgetSettings: BudgetSettingsDTO?
        var payrollSettings: PayrollSettingsDTO?
    }

    struct RecordDTO: Codable {
        var date: Date
        var amount: Double
        var typeRaw: String
        var category: String
        var subCategory: String
        var remark: String
        var countInBudget: Bool
    }

    struct CategoryDTO: Codable {
        var name: String
        var icon: String
        var colorHex: String
        var order: Int
        var parentName: String?
        var isArchived: Bool
        var isSystem: Bool
    }

    struct BankDTO: Codable {
        var name: String
        var icon: String
        var colorHex: String
        var order: Int
    }

    struct DepositDTO: Codable {
        var bankName: String
        var amount: Double
        var startDate: Date
        var years: Double
        var rate: Double
        var interest: Double
        var order: Int
    }

    struct SalaryDTO: Codable {
        var date: Date
        var baseSalary: Double
        var overtimePay: Double
        var oneTimeBonus: Double
        var socialInsurance: Double
        var tax: Double
        var taxRate: Double
    }

    struct BonusDTO: Codable {
        var date: Date
        var bonus: Double
        var tax: Double
        var taxRate: Double
    }

    struct BudgetDTO: Codable {
        var name: String
        var amount: Double
    }

    struct BudgetSettingsDTO: Codable {
        var cycleEnabled: Bool
        var startDay: Int
        var endDay: Int
        var incomeMode: String
    }

    struct PayrollSettingsDTO: Codable {
        var salaryTaxMonthMode: String
    }

    @MainActor
    static func makeData(context: ModelContext) throws -> Data {
        let payload = Payload(
            createdAt: Date(),
            device: UIDeviceName.current,
            hardware: DeviceHardware.current,
            records: try context.fetch(FetchDescriptor<RecordItem>()).map {
                RecordDTO(date: $0.date, amount: $0.amount, typeRaw: $0.typeRaw, category: $0.category, subCategory: $0.subCategory, remark: $0.remark, countInBudget: $0.countInBudget)
            },
            categories: try context.fetch(FetchDescriptor<CategoryItem>()).map {
                CategoryDTO(name: $0.name, icon: $0.icon, colorHex: $0.colorHex, order: $0.order, parentName: $0.parentName, isArchived: $0.isArchived, isSystem: $0.isSystem)
            },
            customBanks: try context.fetch(FetchDescriptor<Bank>())
                .filter { !$0.isSystem }
                .map { BankDTO(name: $0.name, icon: $0.icon, colorHex: $0.colorHex, order: $0.order) },
            deposits: try context.fetch(FetchDescriptor<DepositRecord>()).map {
                DepositDTO(bankName: $0.bankName, amount: $0.amount, startDate: $0.startDate, years: $0.years, rate: $0.rate, interest: $0.interest, order: $0.order)
            },
            salaries: try context.fetch(FetchDescriptor<SalaryRecord>()).map {
                SalaryDTO(date: $0.date, baseSalary: $0.baseSalary, overtimePay: $0.overtimePay, oneTimeBonus: $0.oneTimeBonus, socialInsurance: $0.socialInsurance, tax: $0.tax, taxRate: $0.taxRate)
            },
            bonuses: try context.fetch(FetchDescriptor<AnnualBonus>()).map {
                BonusDTO(date: $0.date, bonus: $0.bonus, tax: $0.tax, taxRate: $0.taxRate)
            },
            budgets: try context.fetch(FetchDescriptor<BudgetItem>()).map {
                BudgetDTO(name: $0.name, amount: $0.amount)
            },
            budgetSettings: {
                let value = BudgetPreferences.load()
                return BudgetSettingsDTO(
                    cycleEnabled: value.cycleEnabled,
                    startDay: value.startDay,
                    endDay: value.endDay,
                    incomeMode: value.incomeMode.rawValue
                )
            }(),
            payrollSettings: {
                let value = PayrollPreferences.load()
                return PayrollSettingsDTO(salaryTaxMonthMode: value.salaryTaxMonthMode.rawValue)
            }()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    @MainActor
    static func restore(data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Payload.self, from: data)

        for item in try context.fetch(FetchDescriptor<RecordItem>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<CategoryItem>()) { context.delete(item) }
        if payload.customBanks != nil {
            for item in try context.fetch(FetchDescriptor<Bank>()) where !item.isSystem {
                context.delete(item)
            }
        }
        for item in try context.fetch(FetchDescriptor<DepositRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<SalaryRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<AnnualBonus>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<BudgetItem>()) { context.delete(item) }

        for item in payload.records {
            context.insert(RecordItem(date: item.date, amount: item.amount, type: RecordType(rawValue: item.typeRaw) ?? .expense, category: item.category, subCategory: item.subCategory, remark: item.remark, countInBudget: item.countInBudget))
        }
        for item in payload.categories {
            context.insert(CategoryItem(name: item.name, icon: item.icon, colorHex: item.colorHex, order: item.order, parentName: item.parentName, isArchived: item.isArchived, isSystem: item.isSystem))
        }
        for item in payload.customBanks ?? [] {
            context.insert(Bank(
                name: item.name,
                icon: item.icon,
                colorHex: item.colorHex,
                order: item.order,
                isSystem: false
            ))
        }
        for item in payload.deposits {
            context.insert(DepositRecord(bankName: item.bankName, amount: item.amount, startDate: item.startDate, years: item.years, rate: item.rate, interest: item.interest, order: item.order))
        }
        for item in payload.salaries {
            context.insert(SalaryRecord(date: item.date, baseSalary: item.baseSalary, overtimePay: item.overtimePay, oneTimeBonus: item.oneTimeBonus, socialInsurance: item.socialInsurance, tax: item.tax, taxRate: item.taxRate))
        }
        for item in payload.bonuses {
            context.insert(AnnualBonus(date: item.date, bonus: item.bonus, tax: item.tax, taxRate: item.taxRate))
        }
        for item in payload.budgets {
            context.insert(BudgetItem(name: item.name, amount: item.amount))
        }

        if let budgetSettings = payload.budgetSettings {
            BudgetPreferences(
                cycleEnabled: budgetSettings.cycleEnabled,
                startDay: budgetSettings.startDay,
                endDay: budgetSettings.endDay,
                incomeMode: BudgetPreferences.IncomeMode(rawValue: budgetSettings.incomeMode) ?? .current
            ).save()
        }

        if let payrollSettings = payload.payrollSettings {
            PayrollPreferences(
                salaryTaxMonthMode: SalaryTaxMonthMode(rawValue: payrollSettings.salaryTaxMonthMode) ?? .current
            ).save()
        }

        try context.save()
    }
}

private struct HardwareInfo: Codable {
    var identifier: String
    var name: String
}

private enum DeviceHardware {
    static var current: HardwareInfo? {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return nil }

        let identifier = withUnsafeBytes(of: &systemInfo.machine) { rawBuffer -> String in
            let data = Data(rawBuffer)
            let end = data.firstIndex(of: 0) ?? data.endIndex
            return String(decoding: data[..<end], as: UTF8.self)
        }
        guard !identifier.isEmpty else { return nil }

        return HardwareInfo(identifier: identifier, name: names[identifier] ?? fallbackName(for: identifier))
    }

    private static func fallbackName(for identifier: String) -> String {
        if identifier == "arm64" || identifier == "x86_64" {
            return "iOS Simulator"
        }
        return identifier
    }

    private static let names: [String: String] = [
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,4": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e"
    ]
}

private enum UIDeviceName {
    static var current: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "iOS"
        #endif
    }
}
