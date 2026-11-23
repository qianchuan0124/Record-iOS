import Foundation

enum Money {
    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return f
    }()

    static func string(_ value: Double) -> String {
        grouped.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func signed(_ value: Double, type: RecordType) -> String {
        "\(type.sign)\(string(value))"
    }

    static func compact(_ value: Double) -> String {
        if abs(value) >= 10_000 {
            return String(format: "%.2f万", value / 10_000)
        }
        return string(value)
    }
}

enum DateText {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f
    }()

    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    static func dayTitle(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L10n.Common.today }
        if cal.isDateInYesterday(date) { return L10n.Common.yesterday }
        return weekdayFormatter.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var startOfMonth: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: self)) ?? self
    }

    var startOfYear: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year], from: self)) ?? self
    }

    func addingMonths(_ value: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: value, to: self) ?? self
    }

    func isSameMonth(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }

    func isSameYear(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .year)
    }
}
