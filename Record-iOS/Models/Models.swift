import Foundation
import SwiftData

enum RecordType: String, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var title: String { self == .expense ? L10n.Common.expense : L10n.Common.income }
    var sign: String { self == .expense ? "-" : "+" }
    var dataTitle: String { self == .expense ? "支出" : "收入" }
}

@Model
final class RecordItem {
    var date: Date = Date()
    var amount: Double = 0
    var typeRaw: String = RecordType.expense.rawValue
    var category: String = ""
    var subCategory: String = ""
    var remark: String = ""
    var countInBudget: Bool = true
    var createdAt: Date = Date()

    init(date: Date = .now,
         amount: Double,
         type: RecordType,
         category: String,
         subCategory: String,
         remark: String = "",
         countInBudget: Bool = true) {
        self.date = date
        self.amount = amount
        self.typeRaw = type.rawValue
        self.category = category
        self.subCategory = subCategory
        self.remark = remark
        self.countInBudget = countInBudget
        self.createdAt = .now
    }

    var type: RecordType { RecordType(rawValue: typeRaw) ?? .expense }
    var signedAmount: Double { type == .expense ? -amount : amount }
}

@Model
final class CategoryItem {
    var name: String = ""
    var icon: String = "其"
    var colorHex: String = "94A3B8"
    var order: Int = 0
    var parentName: String?
    var isArchived: Bool = false
    var isSystem: Bool = false

    init(name: String,
         icon: String,
         colorHex: String,
         order: Int,
         parentName: String? = nil,
         isArchived: Bool = false,
         isSystem: Bool = false) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.parentName = parentName
        self.isArchived = isArchived
        self.isSystem = isSystem
    }
}

@Model
final class Bank {
    var name: String = ""
    var icon: String = "银"
    var colorHex: String = "2E6BD6"
    var order: Int = 0
    var isSystem: Bool = false

    init(name: String, icon: String, colorHex: String, order: Int = 0, isSystem: Bool = false) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.isSystem = isSystem
    }
}

@Model
final class DepositRecord {
    var bankName: String = ""
    var amount: Double = 0
    var startDate: Date = Date()
    var years: Double = 1
    var rate: Double = 0
    var interest: Double = 0
    var order: Int = 0

    init(bankName: String, amount: Double, startDate: Date, years: Double, rate: Double, interest: Double, order: Int = 0) {
        self.bankName = bankName
        self.amount = amount
        self.startDate = startDate
        self.years = years
        self.rate = rate
        self.interest = interest
        self.order = order
    }

    var maturityDate: Date {
        Calendar.current.date(byAdding: .day, value: Int(years * 365.25), to: startDate) ?? startDate
    }
}

@Model
final class SalaryRecord {
    var date: Date = Date()
    var baseSalary: Double = 0
    var overtimePay: Double = 0
    var oneTimeBonus: Double = 0
    var socialInsurance: Double = 0
    var tax: Double = 0
    var taxRate: Double = 3

    init(date: Date, baseSalary: Double, overtimePay: Double, oneTimeBonus: Double, socialInsurance: Double, tax: Double, taxRate: Double) {
        self.date = date
        self.baseSalary = baseSalary
        self.overtimePay = overtimePay
        self.oneTimeBonus = oneTimeBonus
        self.socialInsurance = socialInsurance
        self.tax = tax
        self.taxRate = taxRate
    }

    var gross: Double { baseSalary + overtimePay + oneTimeBonus }
    var netPay: Double { max(0, gross - socialInsurance - tax) }
}

@Model
final class AnnualBonus {
    var date: Date = Date()
    var bonus: Double = 0
    var tax: Double = 0
    var taxRate: Double = 10

    init(date: Date, bonus: Double, tax: Double, taxRate: Double) {
        self.date = date
        self.bonus = bonus
        self.tax = tax
        self.taxRate = taxRate
    }

    var netPay: Double { max(0, bonus - tax) }
}

@Model
final class BudgetItem {
    var name: String = ""
    var amount: Double = 0

    init(name: String, amount: Double) {
        self.name = name
        self.amount = amount
    }
}
