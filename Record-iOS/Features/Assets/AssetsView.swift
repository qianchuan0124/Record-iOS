import SwiftUI
import UIKit
import SwiftData
import UniformTypeIdentifiers

private enum AssetMode: String, CaseIterable, Identifiable {
    case budget
    case salary
    case deposits

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budget: L10n.Assets.budget
        case .salary: L10n.Assets.salary
        case .deposits: L10n.Assets.deposits
        }
    }
}

struct AssetsView: View {
    @State private var didHandleLaunchArgs = false
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \DepositRecord.order) private var deposits: [DepositRecord]
    @Query(sort: \Bank.order) private var banks: [Bank]
    @Query(sort: \SalaryRecord.date, order: .reverse) private var salaries: [SalaryRecord]
    @Query(sort: \AnnualBonus.date, order: .reverse) private var bonuses: [AnnualBonus]
    @Query private var budgets: [BudgetItem]
    @Query private var records: [RecordItem]

    @State private var mode: AssetMode = .budget
    @State private var selectedPayrollYear: Int? = nil
    @State private var orderedDeposits: [DepositRecord] = []
    @State private var showDepositEditor = false
    @State private var showSalaryEditor = false
    @State private var showBonusEditor = false
    @State private var showBudgetEditor = false
    @State private var showBankManage = false
    @State private var editingDeposit: DepositRecord?
    @State private var editingSalary: SalaryRecord?
    @State private var editingBonus: AnnualBonus?
    @State private var editingBudget: BudgetItem?
    @State private var deleteRequest: DeleteRequest?
    @State private var budgetPreferences = BudgetPreferences.load()
    @State private var showBudgetSettings = false

    private var totalDeposit: Double { deposits.reduce(0) { $0 + $1.amount } }
    private var totalInterest: Double { deposits.reduce(0) { $0 + $1.interest } }
    private var bankCount: Int { Set(deposits.map(\.bankName)).count }

    private var sortedDeposits: [DepositRecord] {
        deposits.sorted { $0.order < $1.order }
    }

    private var displayDeposits: [DepositRecord] {
        orderedDeposits.isEmpty ? sortedDeposits : orderedDeposits
    }


    private var allPayrollEntries: [PayrollEntry] {
        let salaryItems = salaries.map(PayrollEntry.salary)
        let bonusItems = bonuses.map(PayrollEntry.bonus)
        return (salaryItems + bonusItems).sorted { $0.date > $1.date }
    }

    private var payrollYears: [Int] {
        let calendar = Calendar.current
        return Array(Set(allPayrollEntries.map { calendar.component(.year, from: $0.date) }))
            .sorted(by: >)
    }

    private var payrollEntries: [PayrollEntry] {
        guard let selectedPayrollYear else { return allPayrollEntries }
        let calendar = Calendar.current
        return allPayrollEntries.filter {
            calendar.component(.year, from: $0.date) == selectedPayrollYear
        }
    }

    private var payrollGross: Double {
        payrollEntries.reduce(0) { total, entry in
            switch entry {
            case .salary(let item): total + item.gross
            case .bonus(let item): total + item.bonus
            }
        }
    }

    private var payrollTax: Double {
        payrollEntries.reduce(0) { total, entry in
            switch entry {
            case .salary(let item): total + item.tax
            case .bonus(let item): total + item.tax
            }
        }
    }

    private var payrollNet: Double {
        payrollEntries.reduce(0) { total, entry in
            switch entry {
            case .salary(let item): total + item.netPay
            case .bonus(let item): total + item.netPay
            }
        }
    }

    private var totalBudget: Double { budgets.reduce(0) { $0 + $1.amount } }

    private var monthExpense: Double {
        let range = budgetPreferences.expenseRange()
        return records
            .filter {
                $0.type == .expense &&
                $0.countInBudget &&
                $0.date >= range.lowerBound &&
                $0.date <= range.upperBound
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthIncome: Double {
        let range = budgetPreferences.incomeRange()
        let salaryIncome = salaries
            .filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
            .reduce(0) { $0 + $1.netPay }
        let bonusIncome = bonuses
            .filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
            .reduce(0) { $0 + $1.netPay }
        return salaryIncome + bonusIncome
    }

    private var availableBudget: Double {
        monthIncome - totalBudget
    }

    private var budgetSpentLabel: String {
        budgetPreferences.cycleEnabled
            ? L10n.Assets.periodSpent(Money.string(monthExpense))
            : L10n.Assets.monthSpent(Money.string(monthExpense))
    }

    private var budgetIncomeLabel: String {
        budgetPreferences.incomeMode == .next
            ? L10n.Assets.budgetIncomeNextShort
            : L10n.Assets.budgetIncome
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 12) {
                HStack {
                    PageTitle(text: L10n.Assets.title)
                    Spacer()
                }
                .padding(.top, 4)

                TopSegmentedControl(items: AssetMode.allCases, title: { $0.title }, selection: $mode)
                    .frame(height: 40)
            }
            .padding(.horizontal, 16)

            switch mode {
            case .deposits:
                depositSection
            case .salary:
                salarySection
            case .budget:
                budgetSection
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            if orderedDeposits.isEmpty { orderedDeposits = sortedDeposits }
            budgetPreferences = BudgetPreferences.load()
        }
        .onChange(of: budgetPreferences) { _, value in
            value.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetPreferencesDidChange)) { _ in
            let loaded = BudgetPreferences.load()
            if loaded != budgetPreferences { budgetPreferences = loaded }
        }
        .onChange(of: deposits.count) { _, _ in
            orderedDeposits = sortedDeposits
        }
        #if DEBUG
        .onAppear {
            guard !didHandleLaunchArgs else { return }
            didHandleLaunchArgs = true
            if CommandLine.arguments.contains("-salary") { mode = .salary }
            if CommandLine.arguments.contains("-budget") { mode = .budget }
            if CommandLine.arguments.contains("-openBanks") { showBankManage = true }
            if CommandLine.arguments.contains("-openDepositEditor") { showDepositEditor = true }
            if CommandLine.arguments.contains("-openSalaryEditor") {
                mode = .salary
                showSalaryEditor = true
            }
            if CommandLine.arguments.contains("-openBonusEditor") {
                mode = .salary
                showBonusEditor = true
            }
            if CommandLine.arguments.contains("-seedBudgetDemo") {
                seedBudgetDemo()
            }
            if CommandLine.arguments.contains("-openBudgetEditor") {
                mode = .budget
                showBudgetEditor = true
            }
            if CommandLine.arguments.contains("-openBudgetEdit"), let first = budgets.first {
                mode = .budget
                editingBudget = first
            }
            if CommandLine.arguments.contains("-openBudgetSettings") {
                mode = .budget
                showBudgetSettings = true
            }
        }
        #endif
        .sheet(isPresented: $showDepositEditor) { DepositEditorView() }
        .sheet(item: $editingDeposit) { DepositEditorView(editing: $0) }
        .sheet(isPresented: $showSalaryEditor) { SalaryEditorView() }
        .sheet(item: $editingSalary) { SalaryEditorView(editing: $0) }
        .sheet(isPresented: $showBonusEditor) { BonusEditorView() }
        .sheet(item: $editingBonus) { BonusEditorView(editing: $0) }
        .sheet(isPresented: $showBudgetEditor) { BudgetEditorView() }
        .sheet(item: $editingBudget) { BudgetEditorView(editing: $0) }
        .sheet(isPresented: $showBudgetSettings) { BudgetSettingsView(settings: $budgetPreferences) }
        .sheet(isPresented: $showBankManage) { BankManageView() }
        .alert(
            Text(deleteRequest?.title ?? L10n.Common.deleteConfirm),
            isPresented: Binding(
                get: { deleteRequest != nil },
                set: { if !$0 { deleteRequest = nil } }
            ),
            presenting: deleteRequest
        ) { request in
            Button(L10n.Common.cancel, role: .cancel) { deleteRequest = nil }
            Button(L10n.Common.delete, role: .destructive) {
                deleteRequest = nil
                request.action()
            }
        } message: { request in
            Text(request.message)
        }
    }

    private func scrolling<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                content()
                Color.clear.frame(height: 110)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var depositSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                StatColumn(title: L10n.Assets.bank, value: "\(bankCount)")
                Divider().frame(height: 28)
                StatColumn(title: L10n.Assets.depositCount, value: "\(deposits.count)")
                Divider().frame(height: 28)
                StatColumn(title: L10n.Assets.totalAmount, value: Money.compact(totalDeposit))
                Divider().frame(height: 28)
                StatColumn(title: L10n.Assets.totalInterest, value: "+\(Money.compact(totalInterest))", color: Theme.income)
            }
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1) }

            HStack(spacing: 8) {
                Text(L10n.Assets.depositList)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L10n.Assets.swipeDragHint)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.horizontal, 2)

            if deposits.isEmpty {
                ScrollView {
                    EmptyHint(text: L10n.Assets.noDeposits)
                        .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)

                depositActions
            } else {
                List {
                    ForEach(displayDeposits) { item in
                        depositRow(item)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove(perform: moveDeposits)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    depositActions
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                        .background(Theme.background)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, deposits.isEmpty ? 38 : 0)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var depositActions: some View {
        HStack(spacing: 10) {
            Button {
                showBankManage = true
            } label: {
                Text(L10n.Assets.bankManage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.brandBorder, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {
                showDepositEditor = true
            } label: {
                Text(L10n.Assets.addDeposit)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func depositRow(_ item: DepositRecord) -> some View {
        depositCard(item)
            .contentShape(Rectangle())
            .onTapGesture {
                editingDeposit = item
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    editingDeposit = item
                } label: {
                    Label(L10n.Assets.update, systemImage: "pencil")
                }
                .tint(Theme.brand)

                Button(role: .destructive) {
                    requestDelete { delete(item, message: L10n.Toast.depositDeleted) }
                } label: {
                    Label(L10n.Common.delete, systemImage: "trash")
                }
            }
    }

    private func moveDeposits(from source: IndexSet, to destination: Int) {
        var ordered = displayDeposits
        ordered.move(fromOffsets: source, toOffset: destination)
        orderedDeposits = ordered
        if persistDepositOrder() {
            toast.show(L10n.Toast.orderSaved)
        } else {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }

    @discardableResult
    private func persistDepositOrder() -> Bool {
        for (index, item) in orderedDeposits.enumerated() where item.order != index {
            item.order = index
        }
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    private func depositCard(_ item: DepositRecord) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                BankLogo(name: item.bankName, icon: bank(for: item).icon, colorHex: bank(for: item).colorHex, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Assets.depositSubtitle(BankName.display(item.bankName), yearsText(item.years)))
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text(L10n.Assets.depositPeriod(DateText.shortFormatter.string(from: item.startDate), DateText.shortFormatter.string(from: item.maturityDate)))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.string(item.amount))
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                    Text("+\(Money.string(item.interest))")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.income)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 16) {
                Text(L10n.Assets.rate("\(String(format: "%.3f", item.rate))%"))
                Text(L10n.Assets.interest(Money.string(item.interest)))
                Spacer()
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.text3)
            .padding(.leading, 44)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1) }
    }

    private var salarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                StatColumn(title: L10n.Assets.payrollGross, value: "+\(Money.compact(payrollGross))", color: Theme.text)
                Divider().frame(height: 28)
                StatColumn(title: L10n.Assets.payrollTax, value: "-\(Money.compact(payrollTax))", color: Theme.expense)
                Divider().frame(height: 28)
                StatColumn(title: L10n.Assets.payrollNet, value: "+\(Money.compact(payrollNet))", color: Theme.income)
            }
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1) }

            HStack {
                Text(L10n.Assets.payrollList)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Menu {
                    Button(L10n.Assets.allYears) {
                        selectedPayrollYear = nil
                    }
                    ForEach(payrollYears, id: \.self) { year in
                        Button("\(year)年") {
                            selectedPayrollYear = year
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPayrollYear.map { "\($0)年" } ?? L10n.Assets.allYears)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surface, in: Capsule())
                    .overlay { Capsule().stroke(Theme.border, lineWidth: 1) }
                }
            }
            .padding(.horizontal, 2)

            if payrollEntries.isEmpty {
                EmptyHint(text: L10n.Assets.noPayroll)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(payrollEntries) { entry in
                        payrollRow(entry)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .contentMargins(.top, 0, for: .scrollContent)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
            }

            HStack(spacing: 10) {
                Button {
                    showSalaryEditor = true
                } label: {
                    Text(L10n.Assets.addSalary)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 13).stroke(Theme.brandBorder, lineWidth: 1) }
                }
                .buttonStyle(.plain)

                Button {
                    showBonusEditor = true
                } label: {
                    Text(L10n.Assets.addBonus)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 32)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func payrollRowContent(_ entry: PayrollEntry) -> some View {
        switch entry {
        case .bonus(let item):
            salaryRow(
                date: item.date,
                tag: L10n.Assets.bonus,
                tagColor: Theme.bonusTag,
                background: Theme.bonusTagBg,
                net: item.netPay,
                tax: item.tax,
                taxRate: item.taxRate,
                detail: L10n.Assets.bonusDetail(Money.string(item.bonus), "\(String(format: "%.0f", item.taxRate))%")
            )
        case .salary(let item):
            salaryRow(
                date: item.date,
                tag: L10n.Assets.salary,
                tagColor: Theme.salaryTag,
                background: Theme.salaryTagBg,
                net: item.netPay,
                tax: item.tax,
                taxRate: item.taxRate,
                detail: L10n.Assets.salaryDetail(Money.string(item.baseSalary), Money.string(item.overtimePay))
            )
        }
    }

    private func payrollRow(_ entry: PayrollEntry) -> some View {
        Group {
            switch entry {
            case .bonus(let item):
                payrollRowContent(entry)
                    .contentShape(Rectangle())
                    .onTapGesture { editingBonus = item }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editingBonus = item
                        } label: {
                            Label(L10n.Common.edit, systemImage: "pencil")
                        }
                        .tint(Theme.brand)

                        Button(role: .destructive) {
                            requestDelete { delete(item, message: L10n.Toast.bonusDeleted) }
                        } label: {
                            Label(L10n.Common.delete, systemImage: "trash")
                        }
                    }
            case .salary(let item):
                payrollRowContent(entry)
                    .contentShape(Rectangle())
                    .onTapGesture { editingSalary = item }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editingSalary = item
                        } label: {
                            Label(L10n.Common.edit, systemImage: "pencil")
                        }
                        .tint(Theme.brand)

                        Button(role: .destructive) {
                            requestDelete { delete(item, message: L10n.Toast.salaryDeleted) }
                        } label: {
                            Label(L10n.Common.delete, systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func taxColor(for rate: Double) -> Color {
        if rate <= 10 {
            return Theme.text3
        }
        if rate < 30 {
            return Theme.warning
        }
        return Theme.expense
    }

    private func salaryRow(date: Date, tag: String, tagColor: Color, background: Color, net: Double, tax: Double, taxRate: Double, detail: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text(DateText.shortFormatter.string(from: date))
                        .font(.system(size: 16, weight: .semibold))
                    Text(tag)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tagColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(background, in: RoundedRectangle(cornerRadius: 5))
                }
                Spacer()
                Text(Money.signed(net, type: .income))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.income)
                    .monospacedDigit()
            }
            HStack {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
                Spacer()
                Text(L10n.Assets.tax(Money.string(tax)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(taxColor(for: taxRate))
                    .monospacedDigit()
            }
        }
        .padding(13)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1) }
    }

    private var budgetSection: some View {
        let remaining = availableBudget - monthExpense
        let progress: Double
        if availableBudget > 0 {
            progress = min(monthExpense / availableBudget, 1)
        } else {
            progress = monthExpense > 0 ? 1 : 0
        }
        let isOverBudget = remaining < 0

        return VStack(spacing: 12) {
            VStack(spacing: 7) {
                Text(isOverBudget ? L10n.Assets.overBudget : L10n.Assets.budgetRemaining)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text3)

                Text(Money.string(abs(remaining)))
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isOverBudget ? Theme.expense : Theme.text)

                Text("\(L10n.Assets.totalBudget(Money.string(availableBudget))) · \(budgetSpentLabel)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text3)

                ProgressView(value: progress)
                    .tint(Theme.brand)
                    .padding(.top, 4)

                HStack {
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(16)
            .background(Theme.summaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.summaryBorder, lineWidth: 1)
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 12) {
                    Button {
                        showBudgetSettings = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.brand)
                                .frame(width: 28, height: 28)
                                .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.Assets.budgetPeriod)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(budgetPreferences.rangeText())
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.text3)
                            }

                            Spacer(minLength: 6)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(budgetPreferences.cycleEnabled ? L10n.Assets.budgetCycle : L10n.Assets.budgetNaturalMonth)
                                Text(budgetPreferences.incomeMode.title)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.chevron)
                        }
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 0) {
                        budgetLegend(
                            title: budgetIncomeLabel,
                            value: "+\(Money.string(monthIncome))",
                            color: Theme.income
                        )
                        Divider().frame(height: 30)
                        budgetLegend(
                            title: L10n.Assets.budgetTotalLabel,
                            value: "-\(Money.string(totalBudget))",
                            color: Theme.expense
                        )
                    }
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }

                    HStack {
                        Text(L10n.Assets.budgetItems)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text3)
                        Spacer()
                    }
                    .padding(.horizontal, 2)

                    if budgets.isEmpty {
                        EmptyHint(text: L10n.Assets.noBudget)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(budgets) { item in
                                budgetRow(item)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingBudget = item }
                            }
                        }
                    }

                    Text(L10n.Assets.budgetNote)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                        .padding(.top, 2)

                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)

            Button {
                showBudgetEditor = true
            } label: {
                Text(L10n.Assets.addBudgetButton)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func budgetRow(_ item: BudgetItem) -> some View {
        HStack(spacing: 10) {
            Text(item.name)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer()
            Text(Money.string(item.amount))
                .font(.system(size: 16, weight: .medium))
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.chevron)
        }
        .frame(height: 46)
        .padding(.horizontal, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private func budgetLegend(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text3)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    #if DEBUG
    private func seedBudgetDemo() {
        let key = "record.budgetDemo.seeded.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let existingNames = Set(budgets.map(\.name))
        let demoBudgets: [(String, Double)] = [
            ("交通", 500),
            ("购物", 1500),
            ("娱乐", 800),
            ("学习", 500),
            ("医疗", 300),
            ("旅行", 2000)
        ]
        for (name, amount) in demoBudgets where !existingNames.contains(name) {
            context.insert(BudgetItem(name: name, amount: amount))
        }

        let demoExpenses: [(String, String, Double)] = [
            ("交通", "打车", 320),
            ("购物", "日用品", 680),
            ("购物", "数码", 599),
            ("娱乐", "电影", 260),
            ("学习", "书籍", 299),
            ("医疗", "药品", 180),
            ("旅行", "周边游", 1800)
        ]
        for (category, subCategory, amount) in demoExpenses {
            context.insert(RecordItem(
                date: Date(),
                amount: amount,
                type: .expense,
                category: category,
                subCategory: subCategory,
                remark: "预算演示数据"
            ))
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
    #endif

    private func bank(for deposit: DepositRecord) -> Bank {
        banks.first { $0.name == deposit.bankName } ??
        Bank(name: deposit.bankName.isEmpty ? L10n.Assets.bankFallback : deposit.bankName, icon: "银", colorHex: "1B7F79")
    }

    private func yearsText(_ years: Double) -> String {
        years == years.rounded() ? String(format: "%.0f", years) : String(format: "%.1f", years)
    }

    private func requestDelete(_ action: @escaping () -> Void) {
        deleteRequest = DeleteRequest(
            title: L10n.Common.deleteConfirm,
            message: L10n.Common.deleteMessage,
            action: action
        )
    }

    private func delete<T: PersistentModel>(_ item: T, message: String) {
        context.delete(item)
        do {
            try context.save()
            toast.show(message)
        } catch {
            toast.show(L10n.Toast.deleteFailed, style: .error)
        }
    }
}

private struct DeleteRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let action: () -> Void
}

private enum PayrollEntry: Identifiable {
    case salary(SalaryRecord)
    case bonus(AnnualBonus)

    var id: PersistentIdentifier {
        switch self {
        case .salary(let item): item.id
        case .bonus(let item): item.id
        }
    }

    var date: Date {
        switch self {
        case .salary(let item): item.date
        case .bonus(let item): item.date
        }
    }
}

private struct DepositEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \Bank.order) private var banks: [Bank]
    @Query(sort: \DepositRecord.order) private var deposits: [DepositRecord]

    var editing: DepositRecord?

    @State private var bankName = "招商银行"
    @State private var amount = ""
    @State private var startDate = Date()
    @State private var years = 3.0
    @State private var rate = "2.750"
    @State private var loaded = false
    @State private var showDatePicker = false
    @State private var bankQuery = ""
    @FocusState private var bankSearchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let bankTileHeight: CGFloat = 60
    private let bankGridSpacing: CGFloat = 4

    private var filteredBanks: [Bank] {
        let query = bankQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return banks }
        return banks.filter { bank in
            if bank.name.localizedCaseInsensitiveContains(query) { return true }
            if BankName.short(bank.name).localizedCaseInsensitiveContains(query) { return true }
            if let preset = BankLogoCatalog.preset(icon: bank.icon, name: bank.name) {
                return preset.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
            }
            return false
        }
    }

    private var bankGridRows: Int {
        min(4, max(1, Int(ceil(Double(max(banks.count, 1)) / 4.0))))
    }

    private var bankGridHeight: CGFloat {
        CGFloat(bankGridRows) * bankTileHeight + CGFloat(max(0, bankGridRows - 1)) * bankGridSpacing
    }

    private var interest: Double {
        let value = Double(amount) ?? 0
        let r = Double(rate) ?? 0
        return (value * r / 100 * years * 100).rounded() / 100
    }

    private var maturityDate: Date {
        Calendar.current.date(byAdding: .day, value: Int(years * 365.25), to: startDate) ?? startDate
    }

    private var canSave: Bool {
        !bankName.trimmingCharacters(in: .whitespaces).isEmpty && (Double(amount) ?? 0) > 0
    }

    private var amountScaleLabel: String? {
        let value = Double(amount) ?? 0
        guard value >= 1000 else { return nil }
        let units: [(threshold: Double, unit: String)] = [
            (100_000_000, "亿"),
            (10_000, "万"),
            (1_000, "千")
        ]
        guard let matched = units.first(where: { value >= $0.threshold }) else { return nil }
        return "\(String(format: "%.2f", value / matched.threshold))\(matched.unit)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                        groupLabel(L10n.Assets.bank)

                        if banks.isEmpty {
                            infoCard {
                                fieldRow(L10n.Bank.name) {
                                    TextField(L10n.Bank.name, text: $bankName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 16))
                                }
                            }
                        } else {
                            bankSearchField

                            if filteredBanks.isEmpty {
                                noBankResults
                                    .frame(height: bankGridHeight, alignment: .top)
                            } else {
                                bankGrid
                            }
                        }

                        groupLabel(L10n.Assets.depositInfo)
                        depositInfoCard

                        interestCard

                        Button {
                            save()
                        } label: {
                            Text(L10n.Assets.saveDeposit)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .opacity(canSave ? 1 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(editing == nil ? L10n.Assets.addDeposit : L10n.Assets.editDeposit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { bankSearchFocused = false }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.large])
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(title: L10n.Assets.depositDate, date: $startDate)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let editing {
                bankName = editing.bankName
                amount = String(format: "%.2f", editing.amount)
                startDate = editing.startDate
                years = editing.years
                rate = String(format: "%.3f", editing.rate)
            } else if bankName.isEmpty, let first = banks.first {
                bankName = first.name
            }
            #if DEBUG
            if CommandLine.arguments.contains("-focusBankSearch") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    bankSearchFocused = true
                }
            }
            #endif
        }
    }

    private var bankGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: bankGridSpacing) {
                ForEach(filteredBanks) { bank in
                    let selected = bank.name == bankName
                    Button {
                        bankName = bank.name
                    } label: {
                        VStack(spacing: 4) {
                            BankLogo(name: bank.name, icon: bank.icon, colorHex: bank.colorHex, size: 26)
                            Text(BankName.short(bank.name))
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Theme.brandDark : Theme.text2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .frame(height: bankTileHeight)
                        .background(
                            selected ? Theme.brandSoft : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selected ? Theme.brandBorder : Theme.border, lineWidth: selected ? 1.5 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
        .frame(height: bankGridHeight)
        .defaultScrollAnchor(.top)
        .scrollIndicators(.visible)
        .id(bankQuery)
    }

    private var bankSearchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text3)

            TextField(L10n.Assets.searchBank, text: $bankQuery)
                .font(.system(size: 16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($bankSearchFocused)

            if !bankQuery.isEmpty {
                Button {
                    bankQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private var noBankResults: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
            Text(L10n.Assets.noBankFound)
                .font(.system(size: 14))
        }
        .foregroundStyle(Theme.text3)
        .frame(maxWidth: .infinity)
        .frame(height: bankTileHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private var depositInfoCard: some View {
        infoCard {
            HStack(spacing: 8) {
                Text(L10n.Common.amount)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text)

                if let amountScaleLabel {
                    Text(amountScaleLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text3)
                        .monospacedDigit()
                }

                Spacer(minLength: 12)

                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: 150)
            }
            .frame(height: 44)
            .padding(.horizontal, 14)

            fieldDivider

            fieldRow(L10n.Assets.depositDate) {
                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(DateText.shortFormatter.string(from: startDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.chevron)
                    }
                }
                .buttonStyle(.plain)
            }

            fieldDivider

            fieldRow(L10n.Assets.depositYears) {
                HStack(spacing: 10) {
                    Button {
                        years = max(0.5, years - 0.5)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.text2)
                            .frame(width: 26, height: 26)
                            .background(Theme.track, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(String(format: "%.2f", years)) \(L10n.Common.yearUnit)")
                        .font(.system(size: 16, weight: .medium))
                        .monospacedDigit()
                        .frame(minWidth: 64)

                    Button {
                        years = min(30, years + 0.5)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.text2)
                            .frame(width: 26, height: 26)
                            .background(Theme.track, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            fieldDivider

            fieldRow(L10n.Assets.rateLabel) {
                HStack(spacing: 4) {
                    TextField("0.000", text: $rate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 82)
                    Text("%")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text3)
                }
            }
        }
    }

    private var interestCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Assets.autoInterest)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text2)
                Spacer()
                Text("+\(Money.string(interest))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.income)
                    .monospacedDigit()
            }

            Text(L10n.Assets.interestNote(DateText.shortFormatter.string(from: maturityDate)))
                .font(.system(size: 13))
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text3)
            .padding(.leading, 2)
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func fieldRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 12)
            content()
        }
        .frame(height: 44)
        .padding(.horizontal, 14)
    }

    private var fieldDivider: some View {
        Divider()
            .overlay(Theme.border)
            .padding(.leading, 14)
    }

    private func save() {
        guard canSave else { return }
        let value = ((Double(amount) ?? 0) * 100).rounded() / 100
        let r = Double(rate) ?? 0
        if let editing {
            editing.bankName = bankName
            editing.amount = value
            editing.startDate = startDate
            editing.years = years
            editing.rate = r
            editing.interest = interest
        } else {
            context.insert(DepositRecord(bankName: bankName, amount: value, startDate: startDate, years: years, rate: r, interest: interest, order: (deposits.map(\.order).max() ?? -1) + 1))
        }
        do {
            try context.save()
            toast.show(editing == nil ? L10n.Toast.depositAdded : L10n.Toast.depositUpdated)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

private struct SalaryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \SalaryRecord.date, order: .reverse) private var salaries: [SalaryRecord]

    var editing: SalaryRecord?

    @State private var date = Date()
    @State private var base = ""
    @State private var overtime = ""
    @State private var bonus = ""
    @State private var social = ""
    @State private var payrollPreferences = PayrollPreferences.load()
    @State private var loaded = false
    @State private var showDatePicker = false

    private var gross: Double {
        (Double(base) ?? 0) + (Double(overtime) ?? 0) + (Double(bonus) ?? 0)
    }

    private var taxInput: SalaryTaxInput {
        SalaryTaxInput(
            date: date,
            baseSalary: Double(base) ?? 0,
            overtimePay: Double(overtime) ?? 0,
            oneTimeBonus: Double(bonus) ?? 0,
            socialInsurance: Double(social) ?? 0
        )
    }

    private var taxResult: SalaryTaxResult {
        calculateSalaryTax(
            current: taxInput,
            currentID: editing?.id,
            salaries: salaries,
            mode: payrollPreferences.salaryTaxMonthMode
        )
    }

    private var tax: Double { taxResult.tax }
    private var taxRate: Double { taxResult.taxRate }
    private var net: Double { taxResult.netPay }

    private var taxMonthModeBinding: Binding<SalaryTaxMonthMode> {
        Binding(
            get: { payrollPreferences.salaryTaxMonthMode },
            set: { value in
                payrollPreferences.salaryTaxMonthMode = value
                payrollPreferences.save()
            }
        )
    }

    private var hasPrevious: Bool {
        editing == nil && !salaries.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    infoCard {
                        fieldRow(L10n.Common.date) {
                            dateButton
                        }

                        fieldDivider
                        moneyField(L10n.Assets.baseSalary, text: $base)
                        fieldDivider
                        moneyField(L10n.Assets.overtime, text: $overtime)
                        fieldDivider
                        moneyField(L10n.Assets.oneTimeBonus, text: $bonus)
                        fieldDivider
                        moneyField(L10n.Assets.socialInsurance, text: $social, negative: true)
                    }

                    if hasPrevious {
                        noteRow(L10n.Assets.salaryPrefillNote, icon: "lightbulb")
                    }

                    groupLabel(L10n.Assets.taxSection)

                    infoCard {
                        fieldRow(L10n.Assets.taxMonthMode) {
                            Picker("", selection: taxMonthModeBinding) {
                                ForEach(SalaryTaxMonthMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                        }

                        fieldDivider

                        fieldRow(L10n.Assets.taxRate) {
                            HStack(spacing: 5) {
                                Text(String(format: "%.2f%%", taxRate))
                                    .font(.system(size: 16, weight: .semibold))
                                    .monospacedDigit()
                                Text(L10n.Assets.taxCumulative)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.text3)
                            }
                        }

                        fieldDivider

                        fieldRow(L10n.Assets.taxLabel) {
                            Text("-\(Money.string(tax))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.expense)
                                .monospacedDigit()
                        }
                    }

                    netCard

                    Text(L10n.Assets.salaryTaxNote)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                hideKeyboard()
            }
            .background(Theme.background)
            .navigationTitle(editing == nil ? L10n.Assets.addSalary : L10n.Assets.editSalary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .disabled(gross <= 0)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.large])
        .overlay {
            if showDatePicker {
                DatePickerOverlay(
                    isPresented: $showDatePicker,
                    title: L10n.Common.date,
                    date: $date
                )
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let editing {
                date = editing.date
                base = String(format: "%.2f", editing.baseSalary)
                overtime = String(format: "%.2f", editing.overtimePay)
                bonus = String(format: "%.2f", editing.oneTimeBonus)
                social = String(format: "%.2f", editing.socialInsurance)
            } else if let last = salaries.first {
                base = String(format: "%.2f", last.baseSalary)
                social = String(format: "%.2f", last.socialInsurance)
            }
        }
    }

    private var dateButton: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: 4) {
                Text(DateText.shortFormatter.string(from: date))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.chevron)
            }
        }
        .buttonStyle(.plain)
    }

    private var netCard: some View {
        HStack(alignment: .center) {
            Text(L10n.Assets.netIncome)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text2)
            Spacer()
            Text("+\(Money.string(net))")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.brand)
                .monospacedDigit()
        }
        .padding(16)
        .background(Theme.summaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.summaryBorder, lineWidth: 1)
        }
    }

    private func moneyField(_ title: String, text: Binding<String>, negative: Bool = false) -> some View {
        let binding = negative ? negativeBinding(text) : text

        return fieldRow(title) {
            TextField("0.00", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(negative ? Theme.expense : Theme.text)
                .monospacedDigit()
                .frame(maxWidth: 160, alignment: .trailing)
        }
    }

    private func negativeBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue.isEmpty ? "" : "-\(source.wrappedValue)" },
            set: { value in
                source.wrappedValue = value
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "−", with: "")
            }
        )
    }

    private func noteRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.brand)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text3)
            .padding(.leading, 2)
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }

    private func fieldRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 12)
            content()
        }
        .frame(height: 48)
        .padding(.horizontal, 14)
    }

    private var fieldDivider: some View {
        Divider()
            .overlay(Theme.border)
            .padding(.leading, 14)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func save() {
        guard gross > 0 else { return }
        if let editing {
            editing.date = date
            editing.baseSalary = Double(base) ?? 0
            editing.overtimePay = Double(overtime) ?? 0
            editing.oneTimeBonus = Double(bonus) ?? 0
            editing.socialInsurance = Double(social) ?? 0
            editing.taxRate = taxRate
            editing.tax = tax
        } else {
            context.insert(SalaryRecord(
                date: date,
                baseSalary: Double(base) ?? 0,
                overtimePay: Double(overtime) ?? 0,
                oneTimeBonus: Double(bonus) ?? 0,
                socialInsurance: Double(social) ?? 0,
                tax: tax,
                taxRate: taxRate
            ))
        }
        do {
            try context.save()
            toast.show(editing == nil ? L10n.Toast.salaryAdded : L10n.Toast.salaryUpdated)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

private struct BonusEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast

    var editing: AnnualBonus?

    @State private var date = Date()
    @State private var bonus = ""
    @State private var loaded = false
    @State private var showDatePicker = false

    private var taxResult: BonusTaxResult {
        calculateBonusTax(Double(bonus) ?? 0)
    }

    private var tax: Double { taxResult.tax }
    private var taxRate: Double { taxResult.taxRate }
    private var net: Double { taxResult.netPay }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    infoCard {
                        fieldRow(L10n.Common.date) {
                            Button {
                                showDatePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text(DateText.shortFormatter.string(from: date))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.chevron)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        fieldDivider

                        fieldRow(L10n.Assets.bonusAmount) {
                            TextField("0.00", text: $bonus)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 16, weight: .semibold))
                                .monospacedDigit()
                                .frame(maxWidth: 160)
                        }

                        fieldDivider

                        fieldRow(L10n.Assets.taxRate) {
                            HStack(spacing: 5) {
                                Text(String(format: "%.2f%%", taxRate))
                                    .font(.system(size: 16, weight: .semibold))
                                    .monospacedDigit()
                                Text(L10n.Assets.bonusTaxSeparate)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.text3)
                            }
                        }

                        fieldDivider

                        fieldRow(L10n.Assets.taxLabel) {
                            Text("-\(Money.string(tax))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.expense)
                                .monospacedDigit()
                        }
                    }

                    HStack(alignment: .center) {
                        Text(L10n.Assets.netIncome)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text2)
                        Spacer()
                        Text("+\(Money.string(net))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.brand)
                            .monospacedDigit()
                    }
                    .padding(16)
                    .background(Theme.summaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.summaryBorder, lineWidth: 1)
                    }

                    Text(L10n.Assets.bonusTaxNote)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(editing == nil ? L10n.Assets.addBonus : L10n.Assets.editBonus)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .disabled((Double(bonus) ?? 0) <= 0)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.fraction(0.66)])
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(title: L10n.Common.date, date: $date)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let editing {
                date = editing.date
                bonus = String(format: "%.2f", editing.bonus)
            }
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }

    private func fieldRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 12)
            content()
        }
        .frame(height: 48)
        .padding(.horizontal, 14)
    }

    private var fieldDivider: some View {
        Divider()
            .overlay(Theme.border)
            .padding(.leading, 14)
    }

    private func save() {
        guard (Double(bonus) ?? 0) > 0 else { return }
        if let editing {
            editing.date = date
            editing.bonus = Double(bonus) ?? 0
            editing.taxRate = taxRate
            editing.tax = tax
        } else {
            context.insert(AnnualBonus(date: date, bonus: Double(bonus) ?? 0, tax: tax, taxRate: taxRate))
        }
        do {
            try context.save()
            toast.show(editing == nil ? L10n.Toast.bonusAdded : L10n.Toast.bonusUpdated)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

private struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast

    var editing: BudgetItem?

    @State private var name = ""
    @State private var amount = ""
    @State private var loaded = false
    @State private var showDeleteConfirm = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    infoCard {
                        fieldRow(L10n.Assets.budgetName) {
                            TextField(L10n.Assets.budgetName, text: $name)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 16))
                        }

                        fieldDivider

                        fieldRow(L10n.Assets.budgetAmount) {
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 16, weight: .semibold))
                                .monospacedDigit()
                                .frame(maxWidth: 160)
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if editing != nil {
                    deleteBudgetButton
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .background(Theme.background)
                }
            }
            .background(Theme.background)
            .navigationTitle(editing == nil ? L10n.Assets.addBudget : L10n.Assets.editBudget)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .disabled(!canSave)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert(L10n.Assets.deleteBudgetTitle, isPresented: $showDeleteConfirm) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Common.delete, role: .destructive) { deleteBudget() }
            } message: {
                Text(L10n.Assets.deleteBudgetMessage(editing?.name ?? ""))
            }
        }
        .tint(Theme.brand)
        .presentationDetents([.height(310), .large])
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let editing {
                name = editing.name
                amount = String(format: "%.2f", editing.amount)
            }
        }
    }

    private var deleteBudgetButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Label(L10n.Assets.deleteBudgetButton, systemImage: "trash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.expense)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.expense.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }

    private func fieldRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 12)
            content()
        }
        .frame(height: 48)
        .padding(.horizontal, 14)
    }

    private var fieldDivider: some View {
        Divider()
            .overlay(Theme.border)
            .padding(.leading, 14)
    }

    private func deleteBudget() {
        guard let editing else { return }
        context.delete(editing)
        do {
            try context.save()
            toast.show(L10n.Toast.budgetDeleted)
            dismiss()
        } catch {
            toast.show(L10n.Toast.deleteFailed, style: .error)
        }
    }

    private func save() {
        guard canSave else { return }
        let value = ((Double(amount) ?? 0) * 100).rounded() / 100
        if let editing {
            editing.name = name.trimmingCharacters(in: .whitespaces)
            editing.amount = value
        } else {
            context.insert(BudgetItem(name: name.trimmingCharacters(in: .whitespaces), amount: value))
        }
        do {
            try context.save()
            toast.show(editing == nil ? L10n.Toast.budgetAdded : L10n.Toast.budgetUpdated)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

private struct BudgetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: BudgetPreferences
    @State private var draft: BudgetPreferences

    init(settings: Binding<BudgetPreferences>) {
        _settings = settings
        _draft = State(initialValue: settings.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    infoCard {
                        HStack {
                            Text(L10n.Assets.budgetPeriod)
                                .font(.system(size: 16))
                            Spacer()
                            Toggle("", isOn: $draft.cycleEnabled)
                                .labelsHidden()
                        }
                        .frame(height: 48)
                        .padding(.horizontal, 14)

                        if draft.cycleEnabled {
                            Divider().padding(.leading, 14)
                            dayRow(
                                title: L10n.Assets.budgetCycleStart,
                                value: $draft.startDay
                            )
                            Divider().padding(.leading, 14)
                            dayRow(
                                title: L10n.Assets.budgetCycleEnd,
                                value: $draft.endDay
                            )
                        }
                    }

                    infoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.Assets.budgetIncomeMode)
                                .font(.system(size: 16))
                            Picker("", selection: $draft.incomeMode) {
                                ForEach(BudgetPreferences.IncomeMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        .padding(14)
                    }

                    Text(L10n.Assets.budgetRange(draft.rangeText()))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    Text(draft.cycleEnabled ? L10n.Assets.budgetCycleHint : L10n.Assets.budgetNaturalMonth)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    Text(L10n.Assets.budgetIncomeHint)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Theme.background)
            .navigationTitle(L10n.Assets.budgetPeriodSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) {
                        settings = draft
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
        .tint(Theme.brand)
        .presentationDetents([.height(420), .large])
    }

    private func dayRow(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
            Spacer()
            Menu {
                ForEach(1...31, id: \.self) { day in
                    Button(L10n.Assets.budgetDay(day)) { value.wrappedValue = day }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(L10n.Assets.budgetDay(value.wrappedValue))
                        .font(.system(size: 16, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text3)
                }
                .foregroundStyle(Theme.text)
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 14)
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }
}

#Preview {
    AssetsView()
        .modelContainer(for: [DepositRecord.self, SalaryRecord.self, AnnualBonus.self, BudgetItem.self, RecordItem.self], inMemory: true)
}
