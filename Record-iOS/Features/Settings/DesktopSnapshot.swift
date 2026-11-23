import Foundation
import SwiftData
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@MainActor
enum DesktopSnapshot {
    private static let presetBanks: [String: String] = {
        guard let url = Bundle.main.url(forResource: "bank-presets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return names
    }()

    private struct CategoryFile: Decodable {
        struct Node: Decodable {
            let label: String?
            let value: String?
            let children: [Node]?
        }

        let defaultTree: [Node]?

        enum CodingKeys: String, CodingKey {
            case defaultTree = "default"
        }
    }

    private struct DesktopBudgetSettings: Decodable {
        var cycleEnabled: Bool?
        var startDay: Int?
        var endDay: Int?
        var incomeMode: String?
    }

    private struct DesktopPayrollSettings: Decodable {
        var salaryTaxMonthMode: String?
    }

    struct BackupInfo {
        var records: Int
        var deposits: Int
        var salaries: Int
        var bonuses: Int
        var budgets: Int
    }

    static func info(for dbURL: URL) -> BackupInfo? {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = handle else {
            if let handle { sqlite3_close(handle) }
            return nil
        }
        defer { sqlite3_close(db) }

        func count(_ table: String) -> Int {
            guard tableExists(db, table) else { return 0 }
            var value = 0
            try? rows(db, "SELECT COUNT(*) FROM \(table) WHERE isDeleted = 0") { stmt in
                value = Int(sqlite3_column_int64(stmt, 0))
            }
            return value
        }

        return BackupInfo(
            records: count("record"),
            deposits: count("deposit_record"),
            salaries: count("salary_record"),
            bonuses: count("annual_bonus"),
            budgets: count("budget_item")
        )
    }

    static func restore(dbURL: URL, context: ModelContext) throws {
        let accessing = dbURL.startAccessingSecurityScopedResource()
        defer { if accessing { dbURL.stopAccessingSecurityScopedResource() } }

        var coordinationError: NSError?
        var coordinatedURL: URL?
        NSFileCoordinator().coordinate(readingItemAt: dbURL, options: [], error: &coordinationError) { coordinated in
            coordinatedURL = coordinated
        }
        guard coordinationError == nil, let fileURL = coordinatedURL else { throw SyncError.invalidDesktopBackup }

        var handle: OpaquePointer?
        guard sqlite3_open_v2(fileURL.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = handle else {
            if let handle { sqlite3_close(handle) }
            throw SyncError.invalidDesktopBackup
        }
        defer { sqlite3_close(db) }

        guard tableExists(db, "record") else { throw SyncError.invalidDesktopBackup }

        for item in try context.fetch(FetchDescriptor<RecordItem>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<CategoryItem>()) { context.delete(item) }
        let existingBanks = try context.fetch(FetchDescriptor<Bank>())
        for item in existingBanks where !item.isSystem { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<DepositRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<SalaryRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<AnnualBonus>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<BudgetItem>()) { context.delete(item) }

        var recordCategories = Set<String>()
        var banks: [Int64: String] = [:]
        var bankNames = Set(existingBanks.filter(\.isSystem).map(\.name))
        var bankOrder = (existingBanks.map(\.order).max() ?? -1) + 1

        func insertBankIfNeeded(_ name: String) {
            guard !name.isEmpty, !bankNames.contains(name) else { return }
            let isSystem = BankSeed.isDefaultBank(name: name)
            let preset = BankSeed.entries.first { $0.name == name }
            context.insert(Bank(
                name: name,
                icon: preset?.icon ?? String(name.prefix(1)),
                colorHex: preset?.colorHex ?? "1B7F79",
                order: bankOrder,
                isSystem: isSystem
            ))
            bankOrder += 1
            bankNames.insert(name)
        }

        if tableExists(db, "deposit_bank") {
            try rows(db, "SELECT id, name FROM deposit_bank WHERE isDeleted = 0") { stmt in
                let id = sqlite3_column_int64(stmt, 0)
                let name = text(stmt, 1)
                guard !name.isEmpty else { return }
                banks[id] = name
                insertBankIfNeeded(name)
            }
        }

        let recordColumns = columns(db, "record")
        let budgetColumn = recordColumns.contains("countInBudget") ? "countInBudget" : "1"
        try rows(db, "SELECT amount, type, date, category, subCategory, remark, \(budgetColumn) FROM record WHERE isDeleted = 0") { stmt in
            let category = text(stmt, 3)
            let subCategory = text(stmt, 4)
            recordCategories.insert("\(category)\u{1F}\(subCategory)")
            context.insert(RecordItem(
                date: Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 2)) / 1000),
                amount: sqlite3_column_double(stmt, 0),
                type: text(stmt, 1) == "收入" ? .income : .expense,
                category: category,
                subCategory: subCategory,
                remark: text(stmt, 5),
                countInBudget: sqlite3_column_int(stmt, 6) != 0
            ))
        }

        if tableExists(db, "deposit_record") {
            let depositColumns = columns(db, "deposit_record")
            let amountColumn = depositColumns.contains("amount") ? "amount" : "0"
            let bankKeyColumn = depositColumns.contains("bankKey") ? "bankKey" : "''"
            let sql = """
                SELECT r.startDate, r.\(amountColumn), r.years, r.rate, r.interest, r.sortOrder,
                       COALESCE(b.name, '') AS joinedBankName, r.\(bankKeyColumn) AS bankKey, r.bankId
                FROM deposit_record r
                LEFT JOIN deposit_bank b ON b.id = r.bankId
                WHERE r.isDeleted = 0
                """
            try rows(db, sql) { stmt in
                let name = bankName(joined: text(stmt, 6), key: text(stmt, 7), bankId: sqlite3_column_int64(stmt, 8), banks: banks)
                insertBankIfNeeded(name)
                context.insert(DepositRecord(
                    bankName: name,
                    amount: sqlite3_column_double(stmt, 1),
                    startDate: Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 0)) / 1000),
                    years: sqlite3_column_double(stmt, 2),
                    rate: sqlite3_column_double(stmt, 3),
                    interest: sqlite3_column_double(stmt, 4),
                    order: Int(sqlite3_column_int64(stmt, 5))
                ))
            }
        }

        if tableExists(db, "salary_record") {
            try rows(db, "SELECT date, baseSalary, overtimePay, oneTimeBonus, socialInsurance, tax, taxRate FROM salary_record WHERE isDeleted = 0") { stmt in
                context.insert(SalaryRecord(
                    date: Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 0)) / 1000),
                    baseSalary: sqlite3_column_double(stmt, 1),
                    overtimePay: sqlite3_column_double(stmt, 2),
                    oneTimeBonus: sqlite3_column_double(stmt, 3),
                    socialInsurance: sqlite3_column_double(stmt, 4),
                    tax: sqlite3_column_double(stmt, 5),
                    taxRate: sqlite3_column_double(stmt, 6)
                ))
            }
        }

        if tableExists(db, "annual_bonus") {
            try rows(db, "SELECT date, bonus, tax, taxRate FROM annual_bonus WHERE isDeleted = 0") { stmt in
                context.insert(AnnualBonus(
                    date: Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 0)) / 1000),
                    bonus: sqlite3_column_double(stmt, 1),
                    tax: sqlite3_column_double(stmt, 2),
                    taxRate: sqlite3_column_double(stmt, 3)
                ))
            }
        }

        if tableExists(db, "budget_item") {
            try rows(db, "SELECT name, amount FROM budget_item WHERE isDeleted = 0") { stmt in
                let name = text(stmt, 0)
                guard !name.isEmpty else { return }
                context.insert(BudgetItem(name: name, amount: sqlite3_column_double(stmt, 1)))
            }
        }

        if tableExists(db, "app_setting") {
            try rows(db, "SELECT value FROM app_setting WHERE key = 'budget' LIMIT 1") { stmt in
                let raw = text(stmt, 0)
                guard let data = raw.data(using: .utf8),
                      let value = try? JSONDecoder().decode(DesktopBudgetSettings.self, from: data) else { return }
                BudgetPreferences(
                    cycleEnabled: value.cycleEnabled ?? false,
                    startDay: value.startDay ?? 26,
                    endDay: value.endDay ?? 25,
                    incomeMode: BudgetPreferences.IncomeMode(rawValue: value.incomeMode ?? "current") ?? .current
                ).save()
            }

            try rows(db, "SELECT value FROM app_setting WHERE key = 'payroll' LIMIT 1") { stmt in
                let raw = text(stmt, 0)
                guard let data = raw.data(using: .utf8),
                      let value = try? JSONDecoder().decode(DesktopPayrollSettings.self, from: data) else { return }
                PayrollPreferences(
                    salaryTaxMonthMode: SalaryTaxMonthMode(rawValue: value.salaryTaxMonthMode ?? "current") ?? .current
                ).save()
            }
        }

        try restoreCategories(near: dbURL, recordCategories: recordCategories, context: context)
        try context.save()
    }

    private static func restoreCategories(near dbURL: URL, recordCategories: Set<String>, context: ModelContext) throws {
        let sidecar = dbURL.deletingPathExtension().appendingPathExtension("categories.json")
        var imported = false

        if let data = try? Data(contentsOf: sidecar), let file = try? JSONDecoder().decode(CategoryFile.self, from: data) {
            let roots = file.defaultTree ?? []
            for (index, root) in roots.enumerated() {
                let name = root.label ?? root.value ?? ""
                guard !name.isEmpty else { continue }
                imported = true
                context.insert(CategoryItem(
                    name: name,
                    icon: CategoryPalette.icon(name),
                    colorHex: CategoryPalette.hex(name),
                    order: index * 100,
                    isSystem: true
                ))
                for (childIndex, child) in (root.children ?? []).enumerated() {
                    let childName = child.label ?? child.value ?? ""
                    guard !childName.isEmpty else { continue }
                    context.insert(CategoryItem(
                        name: childName,
                        icon: CategoryPalette.icon(childName),
                        colorHex: CategoryPalette.hex(childName),
                        order: index * 100 + childIndex + 1,
                        parentName: name,
                        isSystem: true
                    ))
                }
            }
        }

        if !imported {
            CategorySeed.seedIfNeeded(context, existing: [])
        }

        let existing = try context.fetch(FetchDescriptor<CategoryItem>())
        var topLevel = Set(existing.filter { $0.parentName == nil }.map(\.name))
        var children = Set(existing.compactMap { item in item.parentName.map { "\($0)\u{1F}\(item.name)" } })
        var order = (existing.map(\.order).max() ?? 0) + 1

        for key in recordCategories.sorted() {
            let parts = key.split(separator: "\u{1F}", maxSplits: 1, omittingEmptySubsequences: false)
            let category = String(parts[0])
            guard !category.isEmpty else { continue }
            if !topLevel.contains(category) {
                context.insert(CategoryItem(
                    name: category,
                    icon: CategoryPalette.icon(category),
                    colorHex: CategoryPalette.hex(category),
                    order: order
                ))
                topLevel.insert(category)
                order += 1
            }
            guard parts.count == 2 else { continue }
            let subCategory = String(parts[1])
            guard !subCategory.isEmpty else { continue }
            let pair = "\(category)\u{1F}\(subCategory)"
            if !children.contains(pair) {
                context.insert(CategoryItem(
                    name: subCategory,
                    icon: CategoryPalette.icon(subCategory),
                    colorHex: CategoryPalette.hex(subCategory),
                    order: order,
                    parentName: category
                ))
                children.insert(pair)
                order += 1
            }
        }
    }

    private static func bankName(joined: String, key: String, bankId: Int64, banks: [Int64: String]) -> String {
        if !joined.isEmpty { return joined }
        if key.hasPrefix("b:"), let name = presetBanks[String(key.dropFirst(2))] { return name }
        if key.hasPrefix("c:"), let id = Int64(key.dropFirst(2)), let name = banks[id] { return name }
        if let name = banks[bankId] { return name }
        return L10n.Assets.bankFallback
    }

    private static func tableExists(_ db: OpaquePointer, _ table: String) -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1", -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func columns(_ db: OpaquePointer, _ table: String) -> Set<String> {
        var result = Set<String>()
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &stmt, nil) == SQLITE_OK else {
            return result
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = sqlite3_column_text(stmt, 1) {
                result.insert(String(cString: name))
            }
        }
        return result
    }

    private static func rows(_ db: OpaquePointer, _ sql: String, body: (OpaquePointer) -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SyncError.invalidDesktopBackup
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            body(stmt!)
        }
    }

    private static func text(_ stmt: OpaquePointer, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: value)
    }
}
