import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \RecordItem.date, order: .reverse) private var records: [RecordItem]
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]
    @State private var month = Date().startOfMonth
    @State private var showMonthPicker = false
    @State private var showSearch = false
    @State private var showFilter = false
    @State private var filter = LedgerFilter()
    @State private var editing: RecordItem?
    @State private var pendingDelete: RecordItem?
    @State private var didHandleLaunchArgs = false

    private var monthRecords: [RecordItem] {
        records.filter { $0.date.isSameMonth(as: month) }
    }

    private var visibleRecords: [RecordItem] {
        monthRecords.filter { filter.matches($0) }
    }

    private var income: Double {
        visibleRecords.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        visibleRecords.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var dayGroups: [DayGroup] {
        Dictionary(grouping: visibleRecords) { $0.date.startOfDay }
            .map { DayGroup(day: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                SummaryCard(income: income, expense: expense)
                if filter.isActive {
                    filterBar
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 0) {
                    if dayGroups.isEmpty {
                        EmptyHint(text: filter.isActive ? L10n.Ledger.emptyFiltered : L10n.Ledger.emptyMonth)
                    } else {
                        ForEach(dayGroups) { group in
                            daySection(group)
                        }
                    }

                    Color.clear.frame(height: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(records: records, selection: $month)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSearch) {
            SearchRecordsView(records: records)
        }
        .sheet(isPresented: $showFilter) {
            LedgerFilterView(filter: $filter,
                             categories: categories.filter { $0.parentName == nil && !$0.isArchived },
                             monthRecords: monthRecords,
                             month: month)
        }
        .sheet(item: $editing) { record in
            RecordDetailView(record: record)
        }
        .alert(
            L10n.Common.deleteConfirm,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { record in
            Button(L10n.Common.cancel, role: .cancel) { pendingDelete = nil }
            Button(L10n.Common.delete, role: .destructive) {
                delete(record)
                pendingDelete = nil
            }
        } message: { _ in
            Text(L10n.Common.deleteMessage)
        }
        #if DEBUG
        .onAppear {
            guard !didHandleLaunchArgs else { return }
            didHandleLaunchArgs = true
            if CommandLine.arguments.contains("-openSearch") { showSearch = true }
            if CommandLine.arguments.contains("-openFilter") { showFilter = true }
            if CommandLine.arguments.contains("-openDetail") { editing = records.first }
        }
        #endif
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
            Text(filter.summary)
            Spacer()
            Button(L10n.Ledger.clearFilter) {
                filter = LedgerFilter()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.brand)
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.text2)
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button {
                showMonthPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(DateText.monthTitle(month))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text3)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 18) {
                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                Button {
                    showFilter = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(filter.isActive ? Theme.brand : Theme.text2)
                        .overlay(alignment: .topTrailing) {
                            if filter.isActive {
                                Circle()
                                    .fill(Theme.brand)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 3, y: -2)
                            }
                        }
                }
            }
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(Theme.text2)
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func daySection(_ group: DayGroup) -> some View {
        let dayIncome = group.records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let dayExpense = group.records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let isToday = Calendar.current.isDateInToday(group.day)

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(DateText.dayFormatter.string(from: group.day))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                if isToday {
                    Text(L10n.Common.today)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.brandDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.brandSoft, in: Capsule())
                } else {
                    Text(DateText.dayTitle(group.day))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                }
                Spacer()
                HStack(spacing: 10) {
                    if dayIncome > 0 {
                        Text(L10n.Ledger.dayIncome(Money.string(dayIncome))).foregroundStyle(Theme.income)
                    }
                    if dayExpense > 0 {
                        Text(L10n.Ledger.dayExpense(Money.string(dayExpense))).foregroundStyle(Theme.expense)
                    }
                }
                .font(.system(size: 13))
                .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.subtle)

            Divider()

            VStack(spacing: 0) {
                ForEach(group.records) { record in
                    Button {
                        editing = record
                    } label: {
                        recordRow(record)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingDelete = record
                        } label: {
                            Label(L10n.Common.delete, systemImage: "trash")
                        }
                    }

                    if record.id != group.records.last?.id {
                        Divider().padding(.leading, 63)
                    }
                }
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
        .padding(.bottom, 12)
    }

    private func delete(_ record: RecordItem) {
        context.delete(record)
        do {
            try context.save()
            toast.show(L10n.Toast.recordDeleted)
        } catch {
            toast.show(L10n.Toast.deleteFailed, style: .error)
        }
    }

    private func recordRow(_ record: RecordItem) -> some View {
        HStack(spacing: 11) {
            SubcategoryBadge(subcategory: record.subCategory, category: record.category)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.subCategory)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text)
                if !record.remark.isEmpty {
                    Text(record.remark)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(Money.signed(record.amount, type: record.type))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(record.type == .expense ? Theme.expense : Theme.income)
                .monospacedDigit()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

}

private struct DayGroup: Identifiable {
    let day: Date
    let records: [RecordItem]
    var id: Date { day }
}

private struct MonthPickerSheet: View {
    let records: [RecordItem]
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    private var months: [Date] {
        let current = Date().startOfMonth
        return (0..<30).map { current.addingMonths(-$0) }
    }

    var body: some View {
        NavigationStack {
            List(months, id: \.self) { month in
                let items = records.filter { $0.date.isSameMonth(as: month) }
                let income = items.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                let expense = items.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                Button {
                    selection = month
                    dismiss()
                } label: {
                    HStack {
                        Text(DateText.monthTitle(month))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        if items.isEmpty {
                            Text("—")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text3)
                        } else {
                            Text("+\(Money.string(income))")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.income)
                            Text("-\(Money.string(expense))")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.expense)
                        }
                        if Calendar.current.isDate(selection, equalTo: month, toGranularity: .month) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.brand)
                        }
                    }
                    .monospacedDigit()
                }
            }
            .navigationTitle(L10n.Ledger.monthPicker)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
        }
    }
}


struct LedgerFilter {
    var type: RecordType?
    var categories: Set<String> = []
    var minAmount: String = ""
    var maxAmount: String = ""
    var startDate: Date?
    var endDate: Date?

    var isActive: Bool {
        type != nil || !categories.isEmpty || !minAmount.isEmpty || !maxAmount.isEmpty || startDate != nil || endDate != nil
    }

    var summary: String {
        var parts: [String] = []
        if let type { parts.append(type.title) }
        if !categories.isEmpty { parts.append(categories.sorted().joined(separator: "、")) }
        if let min = Double(minAmount) { parts.append(L10n.Ledger.summaryMin(Money.string(min))) }
        if let max = Double(maxAmount) { parts.append(L10n.Ledger.summaryMax(Money.string(max))) }
        if startDate != nil || endDate != nil {
            let start = startDate.map { DateText.shortFormatter.string(from: $0) } ?? L10n.Common.unlimited
            let end = endDate.map { DateText.shortFormatter.string(from: $0) } ?? L10n.Common.unlimited
            parts.append(L10n.Ledger.summaryRange(start, end))
        }
        return parts.isEmpty ? L10n.Ledger.summaryAll : parts.joined(separator: " · ")
    }

    func matches(_ record: RecordItem) -> Bool {
        if let type, record.type != type { return false }
        if !categories.isEmpty && !categories.contains(record.category) { return false }
        if let min = Double(minAmount), record.amount < min { return false }
        if let max = Double(maxAmount), record.amount > max { return false }
        if let startDate, record.date < Calendar.current.startOfDay(for: startDate) { return false }
        if let endDate, let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)), record.date >= nextDay { return false }
        return true
    }
}

private struct LedgerFilterView: View {
    @Binding var filter: LedgerFilter
    let categories: [CategoryItem]
    let monthRecords: [RecordItem]
    let month: Date

    @Environment(\.dismiss) private var dismiss
    @State private var draft = LedgerFilter()
    @State private var typeIndex = 0
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var useCustomDates = false
    @State private var dateField: FilterDateField?
    @State private var detent: PresentationDetent = .height(540)
    @FocusState private var focusedField: AmountField?

    private enum AmountField { case min, max }

    private enum FilterDateField: String, Identifiable {
        case start
        case end

        var id: String { rawValue }
    }

    private let types: [RecordType?] = [nil, .expense, .income]

    private var defaultStart: Date { month.startOfMonth }

    private var defaultEnd: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(month, equalTo: today, toGranularity: .month) { return today }
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: month.startOfMonth) ?? month
    }

    private var effectiveDraft: LedgerFilter {
        var value = draft
        value.type = types[typeIndex]
        value.startDate = useCustomDates ? startDate : nil
        value.endDate = useCustomDates ? endDate : nil
        return value
    }

    private var matchCount: Int {
        monthRecords.filter { effectiveDraft.matches($0) }.count
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionTitle(L10n.Common.type)
                        Picker(L10n.Common.type, selection: $typeIndex) {
                            Text(L10n.Common.all).tag(0)
                            Text(L10n.Common.expense).tag(1)
                            Text(L10n.Common.income).tag(2)
                        }
                        .pickerStyle(.segmented)

                        sectionTitle(L10n.Common.category)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories) { item in
                                    categoryChip(item)
                                }
                            }
                            .padding(.vertical, 1)
                        }

                        sectionTitle(L10n.Ledger.filterAmountRange)
                        HStack(spacing: 10) {
                            amountField(L10n.Ledger.filterMin, text: $draft.minAmount, field: .min)
                            Text("—")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text3)
                            amountField(L10n.Ledger.filterMax, text: $draft.maxAmount, field: .max)
                        }

                        sectionTitle(L10n.Ledger.filterDateRange)
                        VStack(spacing: 0) {
                            dateRow(L10n.Ledger.filterStart, date: startDate, field: .start)
                            Divider().padding(.leading, 16)
                            dateRow(L10n.Ledger.filterEnd, date: endDate, field: .end)
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        }

                        footer(width: geo.size.width)
                            .padding(.top, 2)
                            .opacity(focusedField == nil ? 1 : 0)
                            .allowsHitTesting(focusedField == nil)
                            .animation(.easeInOut(duration: 0.18), value: focusedField)

                        Color.clear.frame(height: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .frame(width: geo.size.width)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L10n.Ledger.filterTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Ledger.filterViewCount(matchCount)) { apply() }
                        .fontWeight(.semibold)
                        .disabled(matchCount == 0)
                }
            }
            .tint(Theme.brand)
        }
        .presentationDetents([.height(540), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .sheet(item: $dateField) { field in
            DatePickerSheet(
                title: field == .start ? L10n.Ledger.filterStart : L10n.Ledger.filterEnd,
                date: dateBinding(for: field)
            )
        }
        .onAppear {
            draft = filter
            typeIndex = types.firstIndex { $0 == filter.type } ?? 0
            if let start = filter.startDate, let end = filter.endDate {
                startDate = start
                endDate = end
                useCustomDates = true
            } else {
                startDate = defaultStart
                endDate = defaultEnd
                useCustomDates = false
            }
            if CommandLine.arguments.contains("-filterFocus") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { focusedField = .min }
            }
        }
    }

    private func dateRow(_ title: String, date: Date, field: FilterDateField) -> some View {
        Button {
            presentDatePicker(for: field)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.text2)
                Spacer()
                Text(DateText.shortFormatter.string(from: date))
                    .foregroundStyle(Theme.text)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.chevron)
            }
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func presentDatePicker(for field: FilterDateField) {
        if detent == .large {
            dateField = field
            return
        }
        detent = .large
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dateField = field
        }
    }

    private func dateBinding(for field: FilterDateField) -> Binding<Date> {
        Binding(
            get: { field == .start ? startDate : endDate },
            set: { value in
                if field == .start {
                    startDate = value
                } else {
                    endDate = value
                }
                useCustomDates = true
            }
        )
    }

    private func categoryChip(_ item: CategoryItem) -> some View {
        let selected = draft.categories.contains(item.name)
        return Button {
            if selected {
                draft.categories.remove(item.name)
            } else {
                draft.categories.insert(item.name)
            }
        } label: {
            Text(item.name)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.brandDark : Theme.text2)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Capsule().fill(selected ? Theme.brandSoft : Theme.surface))
                .overlay {
                    Capsule().stroke(selected ? Theme.brandBorder : Theme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func footer(width: CGFloat) -> some View {
        let clearWidth = max((width - 32 - 10) / 3, 0)
        return HStack(spacing: 10) {
            Button {
                reset()
            } label: {
                Text(L10n.Ledger.filterClear)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text2)
                    .frame(width: clearWidth, height: 46)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {
                apply()
            } label: {
                Text(L10n.Ledger.filterApply)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text3)
    }

    private func amountField(_ placeholder: String, text: Binding<String>, field: AmountField) -> some View {
        TextField(placeholder, text: text)
            .focused($focusedField, equals: field)
            .keyboardType(.decimalPad)
            .font(.system(size: 16))
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }

    private func reset() {
        draft = LedgerFilter()
        typeIndex = 0
        startDate = defaultStart
        endDate = defaultEnd
        useCustomDates = false
    }

    private func apply() {
        filter = effectiveDraft
        dismiss()
    }
}

private enum SearchHistoryStore {
    static let key = "record.search.history.v1"
    static let limit = 10

    static func load() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return value
    }

    static func save(_ value: [String]) {
        guard let data = try? JSONEncoder().encode(Array(value.prefix(limit))) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct SearchRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [RecordItem]
    @State private var keyword = ""
    @State private var submittedKeyword = ""
    @State private var results: [RecordItem] = []
    @State private var history: [String] = []
    @State private var editing: RecordItem?
    @State private var didHandleLaunchArgs = false
    @State private var detent: PresentationDetent = .height(300)
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            header

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text3)

                TextField(L10n.Ledger.searchPlaceholder, text: $keyword)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { submitSearch() }

                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        submittedKeyword = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.text3)
                    }
                    .buttonStyle(.plain)
                }

                Button(L10n.Ledger.searchAction) {
                    submitSearch()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.brand)
                .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }

            content

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background)
        .sheet(item: $editing) { record in
            RecordDetailView(record: record)
        }
        .presentationDetents([.height(300), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onChange(of: keyword) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed != submittedKeyword {
                submittedKeyword = ""
                results = []
            }
        }
        .onChange(of: focused) { _, isFocused in
            guard isFocused else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                detent = .large
            }
        }
        .onAppear {
            history = SearchHistoryStore.load()

            #if DEBUG
            if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("-search=") }) {
                keyword = String(arg.dropFirst("-search=".count))
                submitSearch()
            }
            #endif
        }
    }

    private var header: some View {
        ZStack {
            Text(L10n.Ledger.searchTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .padding(.horizontal, 64)

            HStack {
                Button(L10n.Common.close) {
                    dismiss()
                }
                .foregroundStyle(Theme.brand)

                Spacer()
            }
        }
        .frame(height: 44)
    }

    private func submitSearch(_ rawTerm: String? = nil) {
        let trimmed = (rawTerm ?? keyword).trimmingCharacters(in: .whitespaces)
        focused = false
        guard !trimmed.isEmpty else {
            submittedKeyword = ""
            results = []
            return
        }

        submittedKeyword = trimmed
        results = records.filter {
            $0.category.localizedCaseInsensitiveContains(trimmed) ||
            $0.subCategory.localizedCaseInsensitiveContains(trimmed) ||
            $0.remark.localizedCaseInsensitiveContains(trimmed)
        }
        if rawTerm != nil {
            keyword = trimmed
        }
        remember(trimmed)
    }

    private func remember(_ term: String) {
        history.removeAll { $0.localizedCaseInsensitiveCompare(term) == .orderedSame }
        history.insert(term, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        SearchHistoryStore.save(history)
    }

    private func clearHistory() {
        history.removeAll()
        SearchHistoryStore.save(history)
    }

    private func highlight(_ text: String, key: String, baseColor: Color) -> Text {
        guard !key.isEmpty, !text.isEmpty else {
            return Text(text).foregroundColor(baseColor)
        }

        var result = Text("")
        var rest = Substring(text)

        while let range = rest.range(of: key, options: [.caseInsensitive]) {
            result = result + Text(String(rest[..<range.lowerBound])).foregroundColor(baseColor)
            result = result + Text(String(rest[range])).foregroundColor(Theme.brand).bold()
            rest = rest[range.upperBound...]
        }

        return result + Text(String(rest)).foregroundColor(baseColor)
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.Ledger.searchHistory)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text3)
                Spacer()
                Button(L10n.Common.clear) {
                    clearHistory()
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.brand)
            }
            .padding(.horizontal, 2)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.element) { index, term in
                        Button {
                            submitSearch(term)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.text3)
                                Text(term)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.text3)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < history.count - 1 {
                            Divider().padding(.leading, 27)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var content: some View {
        let key = submittedKeyword
        let items = results

        if key.isEmpty {
            if history.isEmpty {
                EmptyHint(text: L10n.Ledger.searchHint)
            } else {
                historyContent
            }
        } else if items.isEmpty {
            EmptyHint(text: L10n.Ledger.searchEmpty)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, record in
                        Button {
                            editing = record
                        } label: {
                            HStack(spacing: 10) {
                                SubcategoryBadge(subcategory: record.subCategory, category: record.category, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    highlight(record.subCategory, key: key, baseColor: Theme.text)
                                        .font(.system(size: 16, weight: .medium))
                                    (
                                        Text(DateText.shortFormatter.string(from: record.date)).foregroundColor(Theme.text3)
                                        + Text(record.remark.isEmpty ? "" : " · ").foregroundColor(Theme.text3)
                                        + highlight(record.remark, key: key, baseColor: Theme.text3)
                                    )
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                }
                                Spacer()
                                Text(Money.signed(record.amount, type: record.type))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(record.type == .expense ? Theme.expense : Theme.income)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < items.count - 1 {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
