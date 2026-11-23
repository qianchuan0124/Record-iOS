import Foundation

extension Notification.Name {
    static let budgetPreferencesDidChange = Notification.Name("record.budget.preferences.didChange")
}

struct BudgetPreferences: Codable, Equatable {
    enum IncomeMode: String, Codable, CaseIterable, Identifiable {
        case current
        case next

        var id: String { rawValue }

        var title: String {
            switch self {
            case .current: L10n.Assets.budgetIncomeCurrent
            case .next: L10n.Assets.budgetIncomeNext
            }
        }
    }

    var cycleEnabled: Bool = false
    var startDay: Int = 26
    var endDay: Int = 25
    var incomeMode: IncomeMode = .current

    static let storageKey = "record.budget.preferences.v1"

    static func load() -> BudgetPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(BudgetPreferences.self, from: data) else {
            return BudgetPreferences()
        }
        return value.normalized
    }

    func save() {
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        NotificationCenter.default.post(name: .budgetPreferencesDidChange, object: nil)
    }

    var normalized: BudgetPreferences {
        var value = self
        value.startDay = min(31, max(1, value.startDay))
        value.endDay = min(31, max(1, value.endDay))
        return value
    }

    func expenseRange(now: Date = Date()) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let monthStart = now.startOfMonth
        let monthEnd = endOfMonth(monthStart, calendar: calendar)

        guard cycleEnabled else {
            return monthStart...monthEnd
        }

        let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        let start = day(inMonthOf: previousMonth, day: startDay, endOfDay: false, calendar: calendar)
        let end = day(inMonthOf: monthStart, day: endDay, endOfDay: true, calendar: calendar)
        return start...max(start, end)
    }

    func incomeRange(now: Date = Date()) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let offset = incomeMode == .next ? 1 : 0
        let monthStart = calendar.date(byAdding: .month, value: offset, to: now.startOfMonth) ?? now.startOfMonth
        let monthEnd = endOfMonth(monthStart, calendar: calendar)
        return monthStart...monthEnd
    }

    func rangeText(now: Date = Date()) -> String {
        let range = expenseRange(now: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM.dd"
        return "\(formatter.string(from: range.lowerBound)) - \(formatter.string(from: range.upperBound))"
    }

    private func endOfMonth(_ date: Date, calendar: Calendar) -> Date {
        guard let next = calendar.date(byAdding: .month, value: 1, to: date) else { return date }
        return calendar.date(byAdding: .second, value: -1, to: next) ?? next
    }

    private func day(inMonthOf date: Date, day: Int, endOfDay: Bool, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month], from: date)
        let days = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        components.day = min(max(1, day), days)
        let base = calendar.date(from: components) ?? date
        guard endOfDay else { return calendar.startOfDay(for: base) }
        return calendar.date(byAdding: .second, value: -1, to: calendar.date(byAdding: .day, value: 1, to: base) ?? base) ?? base
    }
}
