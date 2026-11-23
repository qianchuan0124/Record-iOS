import SwiftUI
import SwiftData

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast

    let record: RecordItem

    @State private var type: RecordType = .expense
    @State private var amountText = ""
    @State private var category = ""
    @State private var subCategory = ""
    @State private var date = Date()
    @State private var remark = ""
    @State private var countInBudget = true
    @State private var showCategoryPicker = false
    @State private var showDeleteConfirm = false
    @State private var detent: PresentationDetent = .height(540)
    @State private var showDatePicker = false
    @State private var loaded = false
    @FocusState private var amountFocused: Bool
    @FocusState private var remarkFocused: Bool

    private var amountValue: Double { Double(amountText) ?? 0 }

    init(record: RecordItem) {
        self.record = record
        _type = State(initialValue: record.type)
        _amountText = State(initialValue: String(format: "%.2f", record.amount))
        _category = State(initialValue: record.category)
        _subCategory = State(initialValue: record.subCategory)
        _date = State(initialValue: record.date)
        _remark = State(initialValue: record.remark)
        _countInBudget = State(initialValue: record.countInBudget)
        _loaded = State(initialValue: true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    hero
                    fields

                    GeometryReader { geo in
                        let available = geo.size.width - 10
                        HStack(spacing: 10) {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                Label(L10n.Common.delete, systemImage: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.expense)
                                    .frame(width: available / 3)
                                    .frame(height: 48)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Theme.expense.opacity(0.35), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)

                            Button {
                                save()
                            } label: {
                                Text(L10n.Common.save)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: available * 2 / 3)
                                    .frame(height: 48)
                                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(amountValue <= 0)
                        }
                    }
                    .frame(height: 48)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(L10n.Detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerView(category: $category, subCategory: $subCategory)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $date)
            }
            .alert(L10n.Detail.deleteConfirm, isPresented: $showDeleteConfirm) {
                Button(L10n.Common.delete, role: .destructive) { delete() }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Detail.deleteMessage)
            }
        }
        .presentationDetents([.height(540), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onAppear(perform: load)
        #if DEBUG
        .onAppear {
            if CommandLine.arguments.contains("-focusAmount") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    amountFocused = true
                }
            }
            if CommandLine.arguments.contains("-noAutoFocus") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    amountFocused = false
                    remarkFocused = false
                    detent = .height(540)
                }
            }
        }
        #endif
        .onChange(of: amountFocused) { _, focused in
            if focused { detent = .large }
        }
        .onChange(of: remarkFocused) { _, focused in
            if focused { detent = .large }
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            SubcategoryBadge(subcategory: subCategory, category: category, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(subCategory.isEmpty ? L10n.Common.uncategorized : subCategory)
                    .font(.system(size: 16, weight: .semibold))
                Text("\(DateText.shortFormatter.string(from: date)) · \(type.title)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text3)
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                Text(type.sign)
                    .font(.system(size: 20, weight: .bold))
                Text("¥")
                    .font(.system(size: 16, weight: .semibold))
                    .opacity(0.7)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .focused($amountFocused)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(type == .expense ? Theme.expense : Theme.income)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private var fields: some View {
        VStack(spacing: 0) {
            Button {
                detent = .large
                showCategoryPicker = true
            } label: {
                fieldRow {
                    Text(L10n.Common.category)
                        .foregroundStyle(Theme.text2)
                    Spacer()
                    Text("\(category) · \(subCategory)")
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.chevron)
                }
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 16)

            HStack {
                Text(L10n.Common.type)
                    .foregroundStyle(Theme.text2)
                Spacer()
                Menu {
                    ForEach(RecordType.allCases) { item in
                        Button(item.title) { type = item }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(type.title)
                            .foregroundStyle(Theme.text)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)

            Button {
                detent = .large
                showDatePicker = true
            } label: {
                HStack {
                    Text(L10n.Common.date)
                        .foregroundStyle(Theme.text2)
                    Spacer()
                    Text(DateText.shortFormatter.string(from: date))
                        .foregroundStyle(Theme.text)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.chevron)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)

            HStack {
                Text(L10n.Common.remark)
                    .foregroundStyle(Theme.text2)
                Spacer()
                TextField(L10n.Common.addRemark, text: $remark)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.trailing)
                    .focused($remarkFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider().padding(.leading, 16)

            Toggle(isOn: $countInBudget) {
                Text(L10n.Common.countInBudget)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text2)
            }
            .font(.system(size: 16))
            .tint(Theme.income)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
        .font(.system(size: 16))
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func fieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        type = record.type
        amountText = String(format: "%.2f", record.amount)
        category = record.category
        subCategory = record.subCategory
        date = record.date
        remark = record.remark
        countInBudget = record.countInBudget
    }

    private func save() {
        record.date = date
        record.amount = (amountValue * 100).rounded() / 100
        record.typeRaw = type.rawValue
        record.category = category
        record.subCategory = subCategory
        record.remark = remark
        record.countInBudget = countInBudget
        do {
            try context.save()
            toast.show(L10n.Toast.recordUpdated)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }

    private func delete() {
        context.delete(record)
        do {
            try context.save()
            toast.show(L10n.Toast.recordDeleted)
            dismiss()
        } catch {
            toast.show(L10n.Toast.deleteFailed, style: .error)
        }
    }
}

private struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]

    @Binding var category: String
    @Binding var subCategory: String

    @State private var selectedTop = ""
    @State private var keyword = ""

    private var trimmedKeyword: String {
        keyword.trimmingCharacters(in: .whitespaces)
    }

    private var topLevel: [CategoryItem] {
        categories.filter { $0.parentName == nil && !$0.isArchived }
    }

    private var children: [CategoryItem] {
        categories.filter { $0.parentName == selectedTop && !$0.isArchived }
    }

    private var filteredTopLevel: [CategoryItem] {
        guard !trimmedKeyword.isEmpty else { return topLevel }
        return topLevel.filter { item in
            item.name.localizedCaseInsensitiveContains(trimmedKeyword) ||
            categories.contains {
                $0.parentName == item.name && !$0.isArchived && $0.name.localizedCaseInsensitiveContains(trimmedKeyword)
            }
        }
    }

    private var filteredChildren: [CategoryItem] {
        guard !trimmedKeyword.isEmpty else { return children }
        if selectedTop.localizedCaseInsensitiveContains(trimmedKeyword) { return children }
        return children.filter { $0.name.localizedCaseInsensitiveContains(trimmedKeyword) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if filteredTopLevel.isEmpty && !trimmedKeyword.isEmpty {
                    EmptyHint(text: L10n.Detail.searchEmpty)
                        .frame(maxHeight: .infinity)
                } else {
                    GeometryReader { geo in
                        let contentHeight = max(220, geo.size.height - 16)
                        HStack(alignment: .top, spacing: 10) {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(filteredTopLevel) { item in
                                        topRow(item)
                                    }
                                }
                                .padding(8)
                            }
                            .frame(width: 112, height: contentHeight)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1)
                            }

                            ScrollView {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                                    ForEach(filteredChildren) { item in
                                        childButton(item)
                                    }
                                }
                                .padding(8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: contentHeight, alignment: .top)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    }
                }
            }
            .navigationTitle(L10n.Detail.pickCategory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(subCategory.isEmpty)
                }
            }
            .tint(Theme.brand)
            .onAppear {
                if selectedTop.isEmpty {
                    selectedTop = category
                }
            }
            .onChange(of: keyword) { _, _ in
                if !filteredTopLevel.contains(where: { $0.name == selectedTop }),
                   let first = filteredTopLevel.first {
                    selectedTop = first.name
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.text3)
            TextField(L10n.Detail.searchCategory, text: $keyword)
                .font(.system(size: 16))
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.text3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func topRow(_ item: CategoryItem) -> some View {
        let selected = selectedTop == item.name
        return Button {
            selectedTop = item.name
        } label: {
            HStack {
                Text(item.name)
                    .font(.system(size: 16, weight: selected ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Theme.brandSoft : Color.clear)
            )
            .overlay(alignment: .leading) {
                if selected {
                    Rectangle()
                        .fill(Theme.brand)
                        .frame(width: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .foregroundStyle(selected ? Theme.brandDark : Theme.text2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func childButton(_ item: CategoryItem) -> some View {
        Button {
            category = selectedTop
            subCategory = item.name
        } label: {
            HStack(spacing: 5) {
                SubcategoryBadge(subcategory: item.name, category: selectedTop, size: 22)
                Text(item.name)
                    .font(.system(size: 14, weight: subCategory == item.name ? .semibold : .regular))
                    .foregroundStyle(subCategory == item.name ? Theme.brandDark : Theme.text2)
            }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(subCategory == item.name ? Theme.brandSoft : Theme.surface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(subCategory == item.name ? Theme.brandBorder : Theme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
