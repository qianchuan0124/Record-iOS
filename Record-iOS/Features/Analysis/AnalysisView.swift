import SwiftUI
import SwiftData
import Charts

private let analysisBottomSpacing: CGFloat = 80

private enum AnalysisMode: String, CaseIterable, Identifiable {
    case overview
    case yearly
    case timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: L10n.Analysis.overview
        case .yearly: L10n.Analysis.yearly
        case .timeline: L10n.Analysis.timeline
        }
    }
}

struct AnalysisView: View {
    @State private var didHandleLaunchArgs = false
    @Query(sort: \RecordItem.date, order: .reverse) private var records: [RecordItem]
    @Query private var salaries: [SalaryRecord]
    @Query private var bonuses: [AnnualBonus]
    @State private var mode: AnalysisMode = .overview
    @State private var month = Date().startOfMonth
    @State private var showAllOverview = true
    @State private var year = Date().startOfYear
    @State private var path: [CategorySelection] = []
    @State private var selectedRecord: RecordItem?

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 10) {
                header

                switch mode {
                case .overview:
                    overview
                case .yearly:
                    yearly
                case .timeline:
                    scrolling { timeline }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CategorySelection.self) { selection in
                CategoryDetailView(name: selection.name, scope: selection.scope, records: records)
            }
            .sheet(item: $selectedRecord) { record in
                RecordDetailView(record: record)
            }
            #if DEBUG
            .onAppear {
                guard !didHandleLaunchArgs else { return }
                didHandleLaunchArgs = true
                if CommandLine.arguments.contains("-yearly") { mode = .yearly }
                if CommandLine.arguments.contains("-timeline") { mode = .timeline }
                if CommandLine.arguments.contains("-openCategory") {
                    path.append(CategorySelection(name: "居家", scope: .month(month)))
                }
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                PageTitle(text: L10n.Analysis.title)
                Spacer()
            }
            .padding(.top, 4)

            TopSegmentedControl(items: AnalysisMode.allCases, title: \.title, selection: $mode)
                .frame(height: 40)
        }
        .padding(.horizontal, 16)
    }

    private func scrolling<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                content()
                Color.clear.frame(height: analysisBottomSpacing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var monthItems: [RecordItem] {
        records.filter { $0.date.isSameMonth(as: month) }
    }

    private var overviewItems: [RecordItem] {
        showAllOverview ? records : monthItems
    }

    private var overviewScope: CategoryScope {
        showAllOverview ? .all : .month(month)
    }

    private var overview: some View {
        let expenseItems = overviewItems.filter { $0.type == .expense }
        let total = expenseItems.reduce(0) { $0 + $1.amount }
        let slices = Dictionary(grouping: expenseItems, by: \.category)
            .map { Slice(name: $0.key, value: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.value > $1.value }
        let sliceHexes = CategoryPalette.uniqueHexes(for: slices.map(\.name))
        let sliceColors = sliceHexes.mapValues { CategoryPalette.color(forHex: $0) }

        return VStack(spacing: 12) {
            monthSelector

            if slices.isEmpty {
                EmptyHint(text: showAllOverview ? L10n.Analysis.emptyAll : L10n.Analysis.emptyMonth)
                Spacer(minLength: 0)
            } else {
                donut(total: total, slices: slices, colors: sliceColors)

                HStack {
                    Text(L10n.Analysis.categoryDetail)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(L10n.Analysis.clickCategory)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                }
                .padding(.horizontal, 2)

                ScrollView {
                    VStack(spacing: 12) {
                        Card {
                            VStack(spacing: 14) {
                                ForEach(slices) { slice in
                                    categoryRow(slice, total: total, colors: sliceColors, hexes: sliceHexes)
                                }
                            }
                        }

                        Color.clear.frame(height: analysisBottomSpacing)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private var monthSelector: some View {
        HStack {
            Spacer()
            Menu {
                Button(L10n.Analysis.allTime) {
                    selectOverviewMonth(nil)
                }
                ForEach(0..<24, id: \.self) { offset in
                    let item = Date().startOfMonth.addingMonths(-offset)
                    Button(DateText.monthTitle(item)) {
                        selectOverviewMonth(item)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showAllOverview ? L10n.Analysis.allTime : DateText.monthTitle(month))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text2)
                .frame(width: 120, height: 30)
                .background(Theme.surface, in: Capsule())
                .overlay { Capsule().stroke(Theme.border, lineWidth: 1) }
                .contentShape(Capsule())
            }
            Spacer()
        }
    }


    private func selectOverviewMonth(_ date: Date?) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let date {
                month = date
                showAllOverview = false
            } else {
                showAllOverview = true
            }
        }
    }

    private func donut(total: Double, slices: [Slice], colors: [String: Color]) -> some View {
        let diameter: CGFloat = total >= 1_000_000 ? 200 : 180

        return ZStack {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value(L10n.Common.amount, slice.value),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(colors[slice.name] ?? CategoryPalette.color(slice.name))
            }
            .frame(height: diameter)

            VStack(spacing: 2) {
                Text(L10n.Analysis.totalExpense)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text3)
                Text(Money.string(total))
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(width: diameter * 0.56)
            }
        }
        .padding(.vertical, 2)
    }

    private func categoryRow(_ slice: Slice, total: Double, colors: [String: Color], hexes: [String: String]) -> some View {
        Button {
            path.append(CategorySelection(name: slice.name, scope: overviewScope))
        } label: {
            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    CategoryBadge(icon: CategoryPalette.icon(slice.name), colorHex: hexes[slice.name] ?? CategoryPalette.hex(slice.name), size: 30)
                    Text(slice.name)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Money.string(slice.value))
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                        Text(percentText(slice.value, total: total))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text3)
                            .monospacedDigit()
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        Capsule()
                            .fill(colors[slice.name] ?? CategoryPalette.color(slice.name))
                            .frame(width: geo.size.width * (total > 0 ? slice.value / total : 0))
                    }
                }
                .frame(height: 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func percentText(_ value: Double, total: Double) -> String {
        String(format: "%.2f%%", total > 0 ? value / total * 100 : 0)
    }

    private var yearly: some View {
        let data = YearlyData(records: records, salaries: salaries, bonuses: bonuses)
        let currentYear = Calendar.current.component(.year, from: year)
        let bucket = data[currentYear]
        let income = bucket.income + bucket.payroll
        let expense = bucket.expense
        let balance = income - expense
        let years = Array((currentYear - 4)...currentYear)
        let yearSummaries = years.map { y in
            let item = data[y]
            return YearTotal(year: y, income: item.income + item.payroll, expense: item.expense)
        }
        let categorySlices = bucket.categories
            .map { Slice(name: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }

        return VStack(spacing: 12) {
            yearlySummary(income: income, expense: expense, balance: balance)

            ScrollView {
                VStack(spacing: 14) {
                    yearlyChart(summaries: yearSummaries, currentYear: currentYear)
                        .transaction { $0.animation = nil }
                    expenseCalendar(data: data)
                    categorySummary(categorySlices)
                    Color.clear.frame(height: analysisBottomSpacing)
                }
                .padding(.top, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private var yearMenu: some View {
        Menu {
            ForEach(0..<6, id: \.self) { offset in
                let y = Calendar.current.date(byAdding: .year, value: -offset, to: Date().startOfYear) ?? Date()
                Button(L10n.Analysis.yearTitle(Calendar.current.component(.year, from: y))) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { year = y.startOfYear }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(String(Calendar.current.component(.year, from: year)))
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.surface, in: Capsule())
            .overlay { Capsule().stroke(Theme.border, lineWidth: 1) }
        }
    }

    private func yearlySummary(income: Double, expense: Double, balance: Double) -> some View {
        let incomeColor = CategoryPalette.color("交通")
        let expenseColor = CategoryPalette.color("餐饮")

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Analysis.balance)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text3)
                        Text("\(balance < 0 ? "-" : "")¥ \(Money.string(abs(balance)))")
                            .font(.system(size: 29, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 8)
                    yearMenu
                }

                HStack(spacing: 20) {
                    HStack(spacing: 5) {
                        Circle().fill(incomeColor).frame(width: 7, height: 7)
                        Text(L10n.Common.income).font(.system(size: 13)).foregroundStyle(Theme.text3)
                        Text(Money.string(income)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    }
                    HStack(spacing: 5) {
                        Circle().fill(expenseColor).frame(width: 7, height: 7)
                        Text(L10n.Common.expense).font(.system(size: 13)).foregroundStyle(Theme.text3)
                        Text(Money.string(expense)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func yearlyChart(summaries: [YearTotal], currentYear: Int) -> some View {
        let incomeColor = CategoryPalette.color("交通")
        let expenseColor = CategoryPalette.color("餐饮")

        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Analysis.recentYears)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)

                Chart(summaries) { item in
                    BarMark(
                        x: .value(L10n.Analysis.year, "\(item.year)"),
                        y: .value(L10n.Common.income, item.income)
                    )
                    .foregroundStyle(item.year == currentYear ? incomeColor : incomeColor.opacity(0.35))
                    .position(by: .value(L10n.Common.type, L10n.Common.income))
                    .cornerRadius(2)

                    BarMark(
                        x: .value(L10n.Analysis.year, "\(item.year)"),
                        y: .value(L10n.Common.expense, item.expense)
                    )
                    .foregroundStyle(item.year == currentYear ? expenseColor : expenseColor.opacity(0.35))
                    .position(by: .value(L10n.Common.type, L10n.Common.expense))
                    .cornerRadius(2)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text3)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 70)
            }
        }
    }

    private func expenseCalendar(data: YearlyData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Analysis.expenseCalendar)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(1...12, id: \.self) { m in
                    monthCell(m, data: data)
                }
            }
        }
    }

    private func categorySummary(_ slices: [Slice]) -> some View {
        Group {
            if slices.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Analysis.categorySummary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Card {
                        VStack(spacing: 10) {
                            ForEach(slices.prefix(6)) { slice in
                                Button {
                                    path.append(CategorySelection(name: slice.name, scope: .year(year)))
                                } label: {
                                    HStack(spacing: 9) {
                                        CategoryBadge(icon: CategoryPalette.icon(slice.name), colorHex: CategoryPalette.hex(slice.name), size: 30)
                                        Text(slice.name)
                                            .font(.system(size: 16))
                                        Spacer()
                                        Text(Money.string(slice.value))
                                            .font(.system(size: 16, weight: .medium))
                                            .monospacedDigit()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.chevron)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }


    private func monthCell(_ m: Int, data: YearlyData) -> some View {
        let cal = Calendar.current
        let y = cal.component(.year, from: year)
        let date = cal.date(from: DateComponents(year: y, month: m, day: 1)) ?? year
        let item = data[y]
        let expense = item.expenseByMonth[m] ?? 0
        let isCurrent = cal.isDate(date, equalTo: Date(), toGranularity: .month)
        let hasRecords = item.monthsWithRecords.contains(m) || (item.payrollByMonth[m] ?? 0) != 0

        return Button {
            guard hasRecords else { return }
            month = date
            mode = .overview
        } label: {
            VStack(spacing: 2) {
                Text(L10n.Analysis.monthTitle(m))
                    .font(.system(size: 13))
                    .foregroundStyle(isCurrent ? Theme.brandDark : Theme.text3)
                Text(expense > 0 ? Money.compact(expense) : "—")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? Theme.brandDark : Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCurrent ? Theme.brandSoft : Theme.subtle)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasRecords)
    }

    private var timeline: some View {
        let groups = timelineGroups
        return VStack(spacing: 16) {
            if groups.isEmpty {
                EmptyHint(text: L10n.Analysis.yearEmpty)
            } else {
                ForEach(groups) { group in
                    timelineYear(group)
                }
            }
        }
    }

    private var timelineGroups: [TimelineYearGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) {
            calendar.component(.year, from: $0.date)
        }

        return grouped.keys.sorted(by: >).map { year in
            let items = (grouped[year] ?? []).sorted { $0.date < $1.date }
            let expenses = items.filter { $0.type == .expense }
            return TimelineYearGroup(
                year: year,
                total: expenses.reduce(0) { $0 + $1.amount },
                incomeTotal: items.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                records: items,
                events: timelineEvents(for: items)
            )
        }
    }

    private func timelineEvents(for items: [RecordItem]) -> [TimelineEvent] {
        let expenses = items.filter { $0.type == .expense }
        let topExpenses = expenses.sorted { $0.amount > $1.amount }.prefix(3)
        let largestIncome = items
            .filter { $0.type == .income }
            .max { $0.amount < $1.amount }

        let candidates: [(String, RecordItem?)] = [
            (L10n.Analysis.lastExpense, expenses.last),
            (L10n.Analysis.maxExpense, topExpenses.first),
            (L10n.Analysis.largeExpense, topExpenses.dropFirst().first),
            (L10n.Analysis.largeExpense, topExpenses.dropFirst(2).first),
            (L10n.Analysis.maxIncome, largestIncome),
            (L10n.Analysis.firstExpense, expenses.first)
        ]

        var merged: [PersistentIdentifier: TimelineEvent] = [:]
        for (tag, record) in candidates {
            guard let record else { continue }
            if var existing = merged[record.id] {
                existing.tags.append(tag)
                merged[record.id] = existing
            } else {
                merged[record.id] = TimelineEvent(record: record, tags: [tag])
            }
        }

        return merged.values.sorted {
            if $0.record.date != $1.record.date {
                return $0.record.date > $1.record.date
            }
            return $0.record.amount > $1.record.amount
        }
    }

    private func timelineYear(_ group: TimelineYearGroup) -> some View {
        VStack(spacing: 10) {
            Card {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(group.year))
                            .font(.system(size: 20, weight: .bold))
                        Text(L10n.Analysis.recordCount(group.records.count))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text3)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(L10n.Common.expense)
                                .foregroundStyle(Theme.text3)
                            Text(Money.string(group.total))
                                .foregroundStyle(Theme.expense)
                                .monospacedDigit()
                        }
                        if group.incomeTotal > 0 {
                            HStack(spacing: 5) {
                                Text(L10n.Common.income)
                                    .foregroundStyle(Theme.text3)
                                Text(Money.string(group.incomeTotal))
                                    .foregroundStyle(Theme.income)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
            }

            if group.events.isEmpty {
                EmptyHint(text: L10n.Analysis.yearEmpty)
            } else {
                ForEach(group.events) { event in
                    Button {
                        selectedRecord = event.record
                    } label: {
                        TimelineEventCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct TimelineYearGroup: Identifiable {
    let year: Int
    let total: Double
    let incomeTotal: Double
    let records: [RecordItem]
    let events: [TimelineEvent]
    var id: Int { year }
}

private struct TimelineEvent: Identifiable {
    let record: RecordItem
    var tags: [String]
    var id: PersistentIdentifier { record.id }
}


private struct Slice: Identifiable {
    let name: String
    let value: Double
    var id: String { name }
}

private struct YearlyData {
    struct Bucket {
        var income: Double = 0
        var expense: Double = 0
        var payroll: Double = 0
        var categories: [String: Double] = [:]
        var incomeByMonth: [Int: Double] = [:]
        var expenseByMonth: [Int: Double] = [:]
        var payrollByMonth: [Int: Double] = [:]
        var monthsWithRecords: Set<Int> = []
    }

    private var buckets: [Int: Bucket] = [:]

    init(records: [RecordItem], salaries: [SalaryRecord], bonuses: [AnnualBonus]) {
        let calendar = Calendar.current
        for record in records {
            let year = calendar.component(.year, from: record.date)
            let month = calendar.component(.month, from: record.date)
            var bucket = buckets[year] ?? Bucket()
            bucket.monthsWithRecords.insert(month)
            if record.type == .income {
                bucket.income += record.amount
                bucket.incomeByMonth[month, default: 0] += record.amount
            } else {
                bucket.expense += record.amount
                bucket.expenseByMonth[month, default: 0] += record.amount
                bucket.categories[record.category, default: 0] += record.amount
            }
            buckets[year] = bucket
        }

        for salary in salaries {
            let year = calendar.component(.year, from: salary.date)
            let month = calendar.component(.month, from: salary.date)
            var bucket = buckets[year] ?? Bucket()
            bucket.payroll += salary.netPay
            bucket.payrollByMonth[month, default: 0] += salary.netPay
            buckets[year] = bucket
        }

        for bonus in bonuses {
            let year = calendar.component(.year, from: bonus.date)
            let month = calendar.component(.month, from: bonus.date)
            var bucket = buckets[year] ?? Bucket()
            bucket.payroll += bonus.netPay
            bucket.payrollByMonth[month, default: 0] += bonus.netPay
            buckets[year] = bucket
        }
    }

    subscript(year: Int) -> Bucket {
        buckets[year] ?? Bucket()
    }
}

private struct YearTotal: Identifiable {
    let year: Int
    let income: Double
    let expense: Double
    var id: Int { year }
}

private struct TimelineEventCard: View {
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.brand)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    HStack(spacing: 4) {
                        ForEach(event.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.brandDark)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    Spacer(minLength: 6)
                    Text(DateText.shortFormatter.string(from: event.record.date))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                }

                HStack(spacing: 8) {
                    SubcategoryBadge(
                        subcategory: event.record.subCategory,
                        category: event.record.category,
                        size: 30
                    )
                    Text(event.record.subCategory)
                        .font(.system(size: 16, weight: .medium))
                    Spacer(minLength: 6)
                    Text(Money.signed(event.record.amount, type: event.record.type))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(event.record.type == .expense ? Theme.expense : Theme.income)
                        .monospacedDigit()
                }

                if !event.record.remark.isEmpty {
                    Text(event.record.remark)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
        }
    }
}


#Preview {
    AnalysisView()
        .modelContainer(for: [RecordItem.self], inMemory: true)
}


private enum CategoryScope: Hashable {
    case all
    case month(Date)
    case year(Date)

    var key: String {
        switch self {
        case .all: "all"
        case .month(let date): "month-\(date.timeIntervalSince1970)"
        case .year(let date): "year-\(date.timeIntervalSince1970)"
        }
    }

    var title: String {
        switch self {
        case .all: L10n.Common.all
        case .month(let date): DateText.monthTitle(date)
        case .year(let date): L10n.Analysis.yearTitle(Calendar.current.component(.year, from: date))
        }
    }

    var shortTitle: String {
        switch self {
        case .all: L10n.Common.all
        case .month(let date): "\(Calendar.current.component(.month, from: date))月"
        case .year(let date): "\(Calendar.current.component(.year, from: date))年"
        }
    }

    var shareLabel: String {
        switch self {
        case .all: L10n.Analysis.shareAll
        case .month: L10n.Analysis.shareMonth
        case .year: L10n.Analysis.shareYear
        }
    }

    func contains(_ date: Date) -> Bool {
        switch self {
        case .all: true
        case .month(let month): date.isSameMonth(as: month)
        case .year(let year): date.isSameYear(as: year)
        }
    }
}

private struct CategorySelection: Identifiable, Hashable {
    let name: String
    let scope: CategoryScope
    var id: String { name + scope.key }
}

private struct CategoryDetailData {
    let items: [RecordItem]
    let itemsByAmount: [RecordItem]
    let total: Double
    let subTotals: [(name: String, value: Double)]
    let sharePercent: String

    init(name: String, scope: CategoryScope, records: [RecordItem]) {
        var matched: [RecordItem] = []
        var scopedTotal: Double = 0
        for record in records where record.type == .expense && scope.contains(record.date) {
            scopedTotal += record.amount
            if record.category == name {
                matched.append(record)
            }
        }

        var totals: [String: Double] = [:]
        for item in matched {
            totals[item.subCategory, default: 0] += item.amount
        }

        let categoryTotal = matched.reduce(0) { $0 + $1.amount }
        items = matched
        itemsByAmount = matched.sorted {
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            return $0.date > $1.date
        }
        total = categoryTotal
        subTotals = totals
            .map { (name: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
        sharePercent = String(format: "%.2f%%", scopedTotal > 0 ? categoryTotal / scopedTotal * 100 : 0)
    }
}

private struct CategoryDetailView: View {
    let name: String
    let scope: CategoryScope
    private let sourceRecords: [RecordItem]

    @State private var data: CategoryDetailData
    @State private var editing: RecordItem?
    @State private var sortByAmount = false

    init(name: String, scope: CategoryScope, records: [RecordItem]) {
        self.name = name
        self.scope = scope
        sourceRecords = records
        _data = State(initialValue: CategoryDetailData(name: name, scope: scope, records: records))
    }

    var body: some View {
        VStack(spacing: 12) {
            summaryCard

            if data.subTotals.isEmpty {
                EmptyHint(text: L10n.Analysis.noCategoryExpense)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        subcategorySection

                        if !data.items.isEmpty {
                            detailHeader
                            itemsCard
                        }

                        Color.clear.frame(height: analysisBottomSpacing)
                    }
                    .padding(.top, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Theme.background)
        .pushedPageChrome(title: name)
        .onChange(of: sourceRecords.count) { _, _ in
            refresh()
        }
        .sheet(item: $editing, onDismiss: refresh) { record in
            RecordDetailView(record: record)
        }
        .tint(Theme.brand)
    }

    private var displayItems: [RecordItem] {
        sortByAmount ? data.itemsByAmount : data.items
    }

    private func refresh() {
        data = CategoryDetailData(name: name, scope: scope, records: sourceRecords)
    }

    private var summaryCard: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.Analysis.categoryScope(name, scope.shortTitle))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text3)
                Text(Money.string(data.total))
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(scope.shareLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text3)
                Text(data.sharePercent)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private var subcategorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Common.subcategory)
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 2)

            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(data.subTotals.enumerated()), id: \.element.name) { index, item in
                        VStack(spacing: 6) {
                            HStack(alignment: .center, spacing: 8) {
                                SubcategoryBadge(subcategory: item.name, category: name, size: 26)
                                Text(item.name)
                                    .font(.system(size: 16))
                                Spacer()
                                Text(Money.string(item.value))
                                    .font(.system(size: 16, weight: .medium))
                                    .monospacedDigit()
                                Text("· \(percent(item.value / max(data.total, 0.01)))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.text3)
                                    .monospacedDigit()
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.track)
                                    Capsule()
                                        .fill(CategoryPalette.color(name).opacity(max(0.45, 1 - Double(index) * 0.15)))
                                        .frame(width: geo.size.width * (data.total > 0 ? item.value / data.total : 0))
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if index < data.subTotals.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
            }
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 8) {
            Text(L10n.Analysis.detailSection(name))
                .font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 4)
            Text(L10n.Analysis.allRecords(data.items.count))
                .font(.system(size: 12))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)

            sortTabs
        }
        .padding(.horizontal, 2)
    }

    private var sortTabs: some View {
        HStack(spacing: 2) {
            sortTab(L10n.Analysis.sortTimeTab, selected: !sortByAmount) {
                setSortByAmount(false)
            }
            sortTab(L10n.Analysis.sortAmountTab, selected: sortByAmount) {
                setSortByAmount(true)
            }
        }
        .padding(2)
        .background(Theme.track, in: Capsule())
    }

    private func sortTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Theme.text : Theme.text3)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(selected ? Theme.surface : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func setSortByAmount(_ value: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            sortByAmount = value
        }
    }

    private var itemsCard: some View {
        let items = displayItems
        let lastID = items.last?.id

        return Card(padding: 0) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        HStack(spacing: 10) {
                            SubcategoryBadge(
                                subcategory: item.subCategory,
                                category: name,
                                size: 30
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(DateText.dayFormatter.string(from: item.date)) · \(item.subCategory)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                if !item.remark.isEmpty {
                                    Text(item.remark)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.text3)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 8)

                            Text(Money.signed(item.amount, type: item.type))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.expense)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if item.id != lastID {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }
}
