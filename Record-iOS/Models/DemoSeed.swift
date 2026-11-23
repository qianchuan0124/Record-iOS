#if DEBUG
import Foundation
import SwiftData

enum DemoSeed {
    private struct SeededRandom {
        var state: UInt64 = 0x5EED_2026_1119
        mutating func next(_ upper: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(max(1, upper)))
        }
        mutating func double(_ range: ClosedRange<Double>) -> Double {
            let steps = 100
            let value = Double(next(steps)) / Double(steps)
            return (range.lowerBound + (range.upperBound - range.lowerBound) * value * 100).rounded() / 100
        }
    }

    private static let seededKey = "record.demo.seeded.v1"

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        if UserDefaults.standard.bool(forKey: seededKey) { return }

        let existing = (try? context.fetch(FetchDescriptor<RecordItem>())) ?? []
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        let cal = Calendar.current
        let now = Date()
        let monthStart = now.startOfMonth
        let currentDay = cal.component(.day, from: now)

        func daysAgo(_ days: Int) -> Date {
            cal.date(byAdding: .day, value: -days, to: now) ?? now
        }
        func date(monthOffset: Int, day: Int) -> Date {
            let start = monthStart.addingMonths(-monthOffset)
            let base = cal.date(byAdding: .day, value: day - 1, to: start) ?? start
            return cal.date(byAdding: .hour, value: 12, to: base) ?? base
        }

        let currentMonth: [(Int, Double, RecordType, String, String, String)] = [
            (0, 32, .expense, "餐饮", "三餐", "公司楼下"),
            (0, 56, .expense, "交通", "打车", "加班打车回家"),
            (0, 180, .expense, "购物", "日用品", "洗衣液、纸巾"),
            (1, 360, .expense, "人情", "请客", "团队聚餐"),
            (1, 100, .expense, "居家", "话费", "11 月套餐"),
            (1, 68, .expense, "医疗", "药品", "退烧药"),
            (2, 57.6, .expense, "餐饮", "水果", "楼下便利店"),
            (3, 2999, .expense, "购物", "数码", "新款降噪耳机"),
            (5, 3500, .expense, "居家", "房租", "11 月房租"),
            (5, 120, .expense, "居家", "电费", "10 月电费"),
            (8, 45, .expense, "餐饮", "下午茶", "咖啡"),
            (10, 128, .expense, "餐饮", "外卖", "加班晚饭"),
            (12, 89, .expense, "交通", "公交地铁", "通勤"),
            (16, 620, .expense, "购物", "衣帽鞋包", "换季外套"),
            (18, 260, .expense, "娱乐", "电影", "周末电影")
        ]

        for item in currentMonth {
            context.insert(RecordItem(
                date: daysAgo(item.0),
                amount: item.1,
                type: item.2,
                category: item.3,
                subCategory: item.4,
                remark: item.5
            ))
        }

        let templates: [(String, String, ClosedRange<Double>, String)] = [
            ("餐饮", "三餐", 18...58, "公司楼下"),
            ("餐饮", "早餐", 6...18, "包子豆浆"),
            ("餐饮", "外卖", 25...70, "加班晚饭"),
            ("餐饮", "水果", 12...45, "水果店"),
            ("交通", "打车", 18...68, "打车"),
            ("交通", "公交地铁", 4...12, "通勤"),
            ("购物", "日用品", 30...180, "超市补货"),
            ("购物", "衣帽鞋包", 180...760, "换季"),
            ("居家", "话费", 50...150, "月套餐"),
            ("居家", "电费", 60...210, "电费"),
            ("娱乐", "电影", 40...110, "周末电影"),
            ("学习", "书籍", 28...160, "技术书"),
            ("医疗", "药品", 20...120, "常备药"),
            ("人情", "请客", 120...480, "朋友聚餐"),
            ("快递", "邮寄快递", 10...30, "寄件")
        ]

        var random = SeededRandom()
        let days = [2, 4, 6, 8, 11, 13, 16, 18, 20, 22, 24, 26, 28]

        for monthOffset in 0...11 {
            for (index, day) in days.enumerated() {
                if monthOffset == 0 && day >= currentDay - 2 { continue }
                for extra in 0..<2 {
                    let template = templates[(index * 2 + extra + monthOffset * 3) % templates.count]
                    context.insert(RecordItem(
                        date: date(monthOffset: monthOffset, day: day),
                        amount: random.double(template.2),
                        type: .expense,
                        category: template.0,
                        subCategory: template.1,
                        remark: "\(template.3) · \(day)日"
                    ))
                }
            }

            if !(monthOffset == 0 && 10 >= currentDay) {
                context.insert(RecordItem(
                    date: date(monthOffset: monthOffset, day: 10),
                    amount: monthOffset == 4 ? 24800 : 23500,
                    type: .income,
                    category: "金融",
                    subCategory: "工资",
                    remark: "\(monthOffset) 个月前的工资"
                ))
            }
        }

        context.insert(RecordItem(
            date: date(monthOffset: 9, day: 8),
            amount: 52790,
            type: .income,
            category: "金融",
            subCategory: "奖金",
            remark: "2025 年度年终奖"
        ))

        context.insert(DepositRecord(bankName: "招商银行", amount: 100000, startDate: daysAgo(260), years: 3, rate: 2.75, interest: 8250, order: 0))
        context.insert(DepositRecord(bankName: "建设银行", amount: 80000, startDate: daysAgo(150), years: 1, rate: 1.75, interest: 1400, order: 1))
        context.insert(DepositRecord(bankName: "工商银行", amount: 120000, startDate: daysAgo(310), years: 2, rate: 2.10, interest: 5040, order: 2))
        context.insert(DepositRecord(bankName: "宁波银行", amount: 50000, startDate: daysAgo(80), years: 0.5, rate: 1.55, interest: 387.5, order: 3))
        context.insert(DepositRecord(bankName: "交通银行", amount: 60000, startDate: daysAgo(200), years: 1, rate: 1.85, interest: 1110, order: 4))
        context.insert(DepositRecord(bankName: "中信银行", amount: 30000, startDate: daysAgo(30), years: 0.5, rate: 1.65, interest: 247.5, order: 5))

        for offset in 0..<12 {
            let base = 20000.0 + Double(offset % 3) * 500
            let overtime = 600.0 + Double((offset * 137) % 1200)
            let insurance = 3540.0
            let taxable = max(0, base + overtime - insurance - 5000)
            let tax = (taxable * 0.1 * 100).rounded() / 100
            context.insert(SalaryRecord(
                date: date(monthOffset: offset, day: 10),
                baseSalary: base,
                overtimePay: overtime,
                oneTimeBonus: 0,
                socialInsurance: insurance,
                tax: tax,
                taxRate: 10
            ))
        }

        context.insert(AnnualBonus(date: date(monthOffset: 9, day: 8), bonus: 52790, tax: 4790, taxRate: 10))
        context.insert(AnnualBonus(date: date(monthOffset: 21, day: 8), bonus: 46800, tax: 4290, taxRate: 10))

        context.insert(BudgetItem(name: "房租", amount: 3500))
        context.insert(BudgetItem(name: "餐饮", amount: 2000))
        context.insert(BudgetItem(name: "交通", amount: 500))
        context.insert(BudgetItem(name: "购物", amount: 1000))
        context.insert(BudgetItem(name: "娱乐", amount: 600))

        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}
#endif
