import Foundation
import SwiftData

enum SalaryTaxMonthMode: String, Codable, CaseIterable, Identifiable {
    case current
    case previous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current: L10n.Assets.taxMonthCurrent
        case .previous: L10n.Assets.taxMonthPrevious
        }
    }
}

struct SalaryTaxInput {
    var date: Date
    var baseSalary: Double
    var overtimePay: Double
    var oneTimeBonus: Double
    var socialInsurance: Double
}

struct SalaryTaxResult {
    var tax: Double
    var taxRate: Double
    var netPay: Double
}

struct BonusTaxResult {
    var tax: Double
    var taxRate: Double
    var netPay: Double
}

private struct TaxBracket {
    let limit: Double
    let rate: Double
    let deduction: Double
}

private let yearlyTaxBrackets: [TaxBracket] = [
    TaxBracket(limit: 36_000, rate: 0.03, deduction: 0),
    TaxBracket(limit: 144_000, rate: 0.10, deduction: 2_520),
    TaxBracket(limit: 300_000, rate: 0.20, deduction: 16_920),
    TaxBracket(limit: 420_000, rate: 0.25, deduction: 31_920),
    TaxBracket(limit: 660_000, rate: 0.30, deduction: 52_920),
    TaxBracket(limit: 960_000, rate: 0.35, deduction: 85_920),
    TaxBracket(limit: .infinity, rate: 0.45, deduction: 181_920)
]

private let monthlyTaxBrackets: [TaxBracket] = [
    TaxBracket(limit: 3_000, rate: 0.03, deduction: 0),
    TaxBracket(limit: 12_000, rate: 0.10, deduction: 210),
    TaxBracket(limit: 25_000, rate: 0.20, deduction: 1_410),
    TaxBracket(limit: 35_000, rate: 0.25, deduction: 2_660),
    TaxBracket(limit: 55_000, rate: 0.30, deduction: 4_410),
    TaxBracket(limit: 80_000, rate: 0.35, deduction: 7_160),
    TaxBracket(limit: .infinity, rate: 0.45, deduction: 15_160)
]

private let monthlyDeduction = 5_000.0

private func round2(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}

private func salaryIncome(_ input: SalaryTaxInput) -> Double {
    round2(input.baseSalary + input.overtimePay + input.oneTimeBonus)
}

private func taxPeriod(for date: Date, mode: SalaryTaxMonthMode) -> (year: Int, month: Int) {
    let calendar = Calendar.current
    var year = calendar.component(.year, from: date)
    var month = calendar.component(.month, from: date)

    if mode == .previous {
        month -= 1
        if month == 0 {
            month = 12
            year -= 1
        }
    }
    return (year, month)
}

private func bracket(for amount: Double, in brackets: [TaxBracket]) -> TaxBracket {
    brackets.first { amount <= $0.limit } ?? brackets[brackets.count - 1]
}

/// 按居民个人工资薪金累计预扣预缴税率表计算。
/// 工资日期是发薪日；算税月份可选择按发薪当月或上一个归属月计算。
func calculateSalaryTax(
    current: SalaryTaxInput,
    currentID: PersistentIdentifier?,
    salaries: [SalaryRecord],
    mode: SalaryTaxMonthMode
) -> SalaryTaxResult {
    let period = taxPeriod(for: current.date, mode: mode)
    let currentIncome = salaryIncome(current)
    let currentInsurance = max(0, current.socialInsurance)

    var priorIncome = 0.0
    var priorInsurance = 0.0
    var priorTax = 0.0

    for salary in salaries {
        if let currentID, salary.id == currentID { continue }
        let salaryPeriod = taxPeriod(for: salary.date, mode: mode)
        guard salaryPeriod.year == period.year, salaryPeriod.month < period.month else { continue }
        priorIncome += salaryIncome(SalaryTaxInput(
            date: salary.date,
            baseSalary: salary.baseSalary,
            overtimePay: salary.overtimePay,
            oneTimeBonus: salary.oneTimeBonus,
            socialInsurance: salary.socialInsurance
        ))
        priorInsurance += max(0, salary.socialInsurance)
        priorTax += max(0, salary.tax)
    }

    let months = Double(max(0, period.month))
    let taxable = max(0, priorIncome + currentIncome - priorInsurance - currentInsurance - monthlyDeduction * months)
    let currentBracket = bracket(for: taxable, in: yearlyTaxBrackets)
    let cumulativeTax = max(0, taxable * currentBracket.rate - currentBracket.deduction)
    let tax = max(0, round2(cumulativeTax - priorTax))

    return SalaryTaxResult(
        tax: tax,
        taxRate: round2(currentBracket.rate * 100),
        netPay: max(0, round2(currentIncome - currentInsurance - tax))
    )
}

/// 全年一次性奖金按月换算后的综合所得税率表计算。
func calculateBonusTax(_ amount: Double) -> BonusTaxResult {
    let value = max(0, amount)
    guard value > 0 else {
        return BonusTaxResult(tax: 0, taxRate: 0, netPay: 0)
    }

    let currentBracket = bracket(for: value / 12, in: monthlyTaxBrackets)
    let tax = max(0, round2(value * currentBracket.rate - currentBracket.deduction))
    return BonusTaxResult(
        tax: tax,
        taxRate: round2(currentBracket.rate * 100),
        netPay: max(0, round2(value - tax))
    )
}
