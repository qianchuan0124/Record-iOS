import Foundation

enum ExcelImportMode {
    case merge
    case replace
}

struct ExcelRecordData {
    let date: Date
    let type: RecordType
    let category: String
    let subCategory: String
    let amount: Double
    let remark: String
    let countInBudget: Bool
}

struct ExcelBudgetData {
    let name: String
    let amount: Double
}

struct ExcelSalaryData {
    let date: Date
    let baseSalary: Double
    let overtimePay: Double
    let oneTimeBonus: Double
    let socialInsurance: Double
    let tax: Double
    let taxRate: Double
}

struct ExcelBonusData {
    let date: Date
    let bonus: Double
    let tax: Double
    let taxRate: Double
}

struct ExcelDepositData {
    let bankName: String
    let amount: Double
    let startDate: Date
    let years: Double
    let rate: Double
    let interest: Double
}

struct ExcelBankData {
    let name: String
    let icon: String
    let colorHex: String
    let order: Int
    let isSystem: Bool
}

struct ExcelCategoryData {
    let name: String
    let parentName: String?
    let icon: String
    let colorHex: String
    let order: Int
    let isArchived: Bool
    let isSystem: Bool
}

struct ExcelImportPayload {
    var records: [ExcelRecordData] = []
    var budgets: [ExcelBudgetData] = []
    var salaries: [ExcelSalaryData] = []
    var bonuses: [ExcelBonusData] = []
    var deposits: [ExcelDepositData] = []
    var banks: [ExcelBankData] = []
    var categories: [ExcelCategoryData] = []
    var settings: [String: String] = [:]
    var presentSheets: Set<String> = []
    var taxMonthMode: SalaryTaxMonthMode?
    var budgetCycleEnabled: Bool?
    var budgetStartDay: Int?
    var budgetEndDay: Int?
    var budgetIncomeMode: BudgetPreferences.IncomeMode?

    var countItems: [(name: String, count: Int)] {
        var items: [(String, Int)] = []
        if presentSheets.contains("账单") { items.append(("账单", records.count)) }
        if presentSheets.contains("预算") { items.append(("预算", budgets.count)) }
        if presentSheets.contains("工资") { items.append(("工资", salaries.count)) }
        if presentSheets.contains("年终奖") { items.append(("年终奖", bonuses.count)) }
        if presentSheets.contains("存款") { items.append(("存款", deposits.count)) }
        if presentSheets.contains("银行") { items.append(("银行", banks.count)) }
        if presentSheets.contains("分类") { items.append(("分类", categories.count)) }
        if presentSheets.contains("设置") { items.append(("设置", settings.count)) }
        return items
    }

    var isEmpty: Bool {
        presentSheets.isEmpty
    }
}

enum ExcelImportParser {
    static func payload(from sheets: [String: [[String]]]) -> ExcelImportPayload {
        var payload = ExcelImportPayload()

        if let table = ImportTable(rows: sheets["账单"] ?? [], required: ["日期", "类型", "分类", "子分类", "金额"]) {
            payload.presentSheets.insert("账单")
            for row in table.rows {
                guard let date = date(table.value(row, "日期")),
                      let amount = number(table.value(row, "金额")),
                      amount > 0,
                      let type = recordType(table.value(row, "类型")),
                      !table.value(row, "分类").isEmpty,
                      !table.value(row, "子分类").isEmpty else { continue }
                payload.records.append(ExcelRecordData(
                    date: date,
                    type: type,
                    category: table.value(row, "分类"),
                    subCategory: table.value(row, "子分类"),
                    amount: (amount * 100).rounded() / 100,
                    remark: table.value(row, "备注"),
                    countInBudget: table.value(row, "计入预算") != "否"
                ))
            }
        }

        if let table = ImportTable(rows: sheets["预算"] ?? [], required: ["预算名称", "预算金额"]) {
            payload.presentSheets.insert("预算")
            for row in table.rows {
                let name = table.value(row, "预算名称")
                guard !name.isEmpty, let amount = number(table.value(row, "预算金额")) else { continue }
                payload.budgets.append(ExcelBudgetData(name: name, amount: amount))
            }
        }

        if let table = ImportTable(rows: sheets["工资"] ?? [], required: ["日期", "基本工资"]) {
            payload.presentSheets.insert("工资")
            for row in table.rows {
                guard let date = date(table.value(row, "日期")) else { continue }
                payload.salaries.append(ExcelSalaryData(
                    date: date,
                    baseSalary: number(table.value(row, "基本工资")) ?? 0,
                    overtimePay: number(table.value(row, "加班费")) ?? 0,
                    oneTimeBonus: number(table.value(row, "一次性奖金")) ?? 0,
                    socialInsurance: number(table.value(row, "五险一金")) ?? 0,
                    tax: number(table.value(row, "税额")) ?? 0,
                    taxRate: number(table.value(row, ["税率(%)", "税率"])) ?? 0
                ))
            }
        }

        if let table = ImportTable(rows: sheets["年终奖"] ?? [], required: ["日期", "奖金"]) {
            payload.presentSheets.insert("年终奖")
            for row in table.rows {
                guard let date = date(table.value(row, "日期")) else { continue }
                payload.bonuses.append(ExcelBonusData(
                    date: date,
                    bonus: number(table.value(row, "奖金")) ?? 0,
                    tax: number(table.value(row, "税额")) ?? 0,
                    taxRate: number(table.value(row, ["税率(%)", "税率"])) ?? 0
                ))
            }
        }

        if let table = ImportTable(rows: sheets["存款"] ?? [], required: ["银行", "金额", "存款时间"]) {
            payload.presentSheets.insert("存款")
            for row in table.rows {
                let bank = table.value(row, "银行")
                guard !bank.isEmpty,
                      let amount = number(table.value(row, "金额")),
                      let startDate = date(table.value(row, "存款时间")) else { continue }
                let years = number(table.value(row, "年限")) ?? 1
                let rate = number(table.value(row, ["利率(%)", "利率"])) ?? 0
                let interest = number(table.value(row, "利息"))
                    ?? (amount * rate / 100 * years * 100).rounded() / 100
                payload.deposits.append(ExcelDepositData(
                    bankName: bank,
                    amount: amount,
                    startDate: startDate,
                    years: years,
                    rate: rate,
                    interest: interest
                ))
            }
        }

        if let table = ImportTable(rows: sheets["银行"] ?? [], required: ["名称"]) {
            payload.presentSheets.insert("银行")
            for (index, row) in table.rows.enumerated() {
                let name = table.value(row, "名称")
                guard !name.isEmpty else { continue }
                payload.banks.append(ExcelBankData(
                    name: name,
                    icon: table.value(row, "图标").ifEmpty("银"),
                    colorHex: table.value(row, "颜色").ifEmpty("2E6BD6"),
                    order: integer(table.value(row, "排序")) ?? index,
                    isSystem: table.value(row, "类型") == "内置"
                ))
            }
        }

        if let table = ImportTable(rows: sheets["分类"] ?? [], required: ["名称"]) {
            payload.presentSheets.insert("分类")
            for (index, row) in table.rows.enumerated() {
                let name = table.value(row, "名称")
                guard !name.isEmpty else { continue }
                let parent = table.value(row, "父分类")
                payload.categories.append(ExcelCategoryData(
                    name: name,
                    parentName: parent.isEmpty ? nil : parent,
                    icon: table.value(row, "图标").ifEmpty("其"),
                    colorHex: table.value(row, "颜色").ifEmpty("94A3B8"),
                    order: integer(table.value(row, "排序")) ?? index,
                    isArchived: boolean(table.value(row, "归档")),
                    isSystem: boolean(table.value(row, "系统分类"))
                ))
            }
        }

        if let table = ImportTable(rows: sheets["设置"] ?? [], required: ["设置项", "值"]) {
            payload.presentSheets.insert("设置")
            for row in table.rows {
                let key = table.value(row, "设置项")
                guard !key.isEmpty else { continue }
                payload.settings[key] = table.value(row, "值")
            }
            applySettings(to: &payload)
        }

        return payload
    }

    private static func applySettings(to payload: inout ExcelImportPayload) {
        if let mode = payload.settings["算税月份"] {
            payload.taxMonthMode = mode.contains("上") ? .previous : .current
        }

        if let cycle = payload.settings["预算周期"] {
            if cycle.contains("自然月") {
                payload.budgetCycleEnabled = false
            } else {
                let days = cycle.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap(Int.init)
                if days.count >= 2 {
                    payload.budgetCycleEnabled = true
                    payload.budgetStartDay = days[0]
                    payload.budgetEndDay = days[1]
                }
            }
        }

        if let income = payload.settings["收入计算"] {
            payload.budgetIncomeMode = income.contains("下月") ? .next : .current
        }
    }

    private static func recordType(_ text: String) -> RecordType? {
        if text == "支出" { return .expense }
        if text == "收入" { return .income }
        return RecordType(rawValue: text.lowercased())
    }

    private static func date(_ text: String) -> Date? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let serial = Double(value),
           serial >= 1,
           serial < 100_000,
           !value.contains("-"),
           !value.contains("/") {
            let date = Date(timeIntervalSince1970: (serial - 25_569) * 86_400)
            return Calendar.current.startOfDay(for: date)
        }

        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyy/M/d", "yyyy/MM/dd"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private static func number(_ text: String) -> Double? {
        let value = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(value)
    }

    private static func integer(_ text: String) -> Int? {
        number(text).map { Int($0) }
    }

    private static func boolean(_ text: String) -> Bool {
        ["是", "1", "true", "TRUE"].contains(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct ImportTable {
    let header: [String]
    let rows: [[String]]

    init?(rows: [[String]], required: [String]) {
        guard let first = rows.first else { return nil }
        let header = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard required.allSatisfy({ header.contains($0) }) else { return nil }
        self.header = header
        self.rows = rows.dropFirst().filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    func value(_ row: [String], _ key: String) -> String {
        guard let index = header.firstIndex(of: key), row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func value(_ row: [String], _ keys: [String]) -> String {
        for key in keys {
            let value = value(row, key)
            if !value.isEmpty { return value }
        }
        return ""
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
