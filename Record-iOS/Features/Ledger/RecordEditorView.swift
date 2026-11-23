import SwiftUI
import SwiftData

struct RecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]

    var editing: RecordItem?

    @State private var type: RecordType = .expense
    @State private var amountText = ""
    @State private var category = ""
    @State private var subCategory = ""
    @State private var date = Date()
    @State private var remark = ""
    @State private var countInBudget = true
    @State private var loaded = false
    @State private var showDeleteConfirm = false
    @State private var showDatePicker = false
    @State private var detent: PresentationDetent = .height(540)
    @FocusState private var amountFocused: Bool
    @FocusState private var remarkFocused: Bool

    private var topCategories: [CategoryItem] {
        categories.filter { $0.parentName == nil && !$0.isArchived }
    }

    private var subCategories: [CategoryItem] {
        categories.filter { $0.parentName == category && !$0.isArchived }
    }

    private var amountValue: Double {
        Double(amountText) ?? 0
    }

    private var canSave: Bool {
        amountValue > 0 && !category.isEmpty && !subCategory.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            segmented
                            amountBlock
                            categoryRow
                            subCategoryChips
                            detailFields

                            if editing != nil {
                                Button(role: .destructive) {
                                    showDeleteConfirm = true
                                } label: {
                                    Label(L10n.Editor.delete, systemImage: "trash")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.expense)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(Theme.expense.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: remarkFocused) { _, focused in
                        guard focused else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo("remarkField", anchor: .center)
                            }
                        }
                    }
                }

            }
            .navigationTitle(editing == nil ? L10n.Editor.newTitle : L10n.Editor.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) {
                        amountFocused = false
                        remarkFocused = false
                    }
                }
            }
        }
        .presentationDetents([.height(540), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .onAppear(perform: load)
        .onChange(of: amountFocused) { _, focused in
            if focused { detent = .large }
        }
        .onChange(of: remarkFocused) { _, focused in
            if focused { detent = .large }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date)
        }
        .alert(L10n.Detail.deleteConfirm, isPresented: $showDeleteConfirm) {
            Button(L10n.Common.delete, role: .destructive) { deleteRecord() }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Detail.deleteMessage)
        }
    }

    private var segmented: some View {
        Picker(L10n.Common.type, selection: $type) {
            ForEach(RecordType.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var amountBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("¥")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.text3)
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .focused($amountFocused)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            remarkFocused = false
            amountFocused = true
        }
    }

    private var categoryRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(topCategories) { item in
                        Button {
                            amountFocused = false
                            remarkFocused = false
                            category = item.name
                            subCategory = subCategories.first?.name ?? ""
                        } label: {
                            VStack(spacing: 5) {
                                CategoryBadge(icon: item.icon, colorHex: item.colorHex, size: 40)
                                    .overlay {
                                        if category == item.name {
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .stroke(Theme.selectionBorder, lineWidth: 1.5)
                                                .padding(-2)
                                        }
                                    }
                                Text(item.name)
                                    .font(.system(size: 13, weight: category == item.name ? .semibold : .regular))
                                    .foregroundStyle(category == item.name ? Theme.brandDark : Theme.text2)
                                    .lineLimit(1)
                            }
                            .frame(width: 54)
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .focusable(false)
                        .id(item.name)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 5)
            }
            .onAppear {
                guard !category.isEmpty else { return }
                proxy.scrollTo(category, anchor: .center)
            }
            .onChange(of: category) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var subCategoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(subCategories) { item in
                    Button {
                        amountFocused = false
                        remarkFocused = false
                        subCategory = item.name
                    } label: {
                        HStack(spacing: 5) {
                            SubcategoryBadge(subcategory: item.name, category: category, size: 22)
                            Text(item.name)
                                .font(.system(size: 14, weight: subCategory == item.name ? .semibold : .regular))
                                .foregroundStyle(subCategory == item.name ? Theme.brandDark : Theme.text2)
                        }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(subCategory == item.name ? Theme.brandSoft : Theme.surface)
                            )
                            .overlay {
                                Capsule().stroke(subCategory == item.name ? Theme.brandBorder : Theme.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var detailFields: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                Button {
                    amountFocused = false
                    remarkFocused = false
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
                .padding(.vertical, 11)

                Divider()

                HStack {
                    Text(L10n.Common.remark)
                        .foregroundStyle(Theme.text2)
                    Spacer()
                    TextField(L10n.Common.addRemark, text: $remark)
                        .multilineTextAlignment(.trailing)
                        .focused($remarkFocused)
                        .submitLabel(.done)
                        .onSubmit { remarkFocused = false }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .id("remarkField")

                Divider()

                Toggle(isOn: $countInBudget) {
                    Text(L10n.Common.countInBudget)
                        .foregroundStyle(Theme.text2)
                }
                .tint(Theme.income)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
            }
            .font(.system(size: 16))
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true

        if let editing {
            type = editing.type
            amountText = String(format: "%.2f", editing.amount)
            category = editing.category
            subCategory = editing.subCategory
            date = editing.date
            remark = editing.remark
            countInBudget = editing.countInBudget
        } else {
            if let first = topCategories.first {
                category = first.name
                subCategory = categories.first { $0.parentName == first.name && !$0.isArchived }?.name ?? ""
            }
        }
    }

    private func deleteRecord() {
        guard let editing else { return }
        context.delete(editing)
        do {
            try context.save()
            toast.show(L10n.Toast.recordDeleted)
            dismiss()
        } catch {
            toast.show(L10n.Toast.deleteFailed, style: .error)
        }
    }

    private func save() {
        let value = (amountValue * 100).rounded() / 100
        let isNew = editing == nil

        if let editing {
            editing.date = date
            editing.amount = value
            editing.typeRaw = type.rawValue
            editing.category = category
            editing.subCategory = subCategory
            editing.remark = remark
            editing.countInBudget = countInBudget
        } else {
            let record = RecordItem(
                date: date,
                amount: value,
                type: type,
                category: category,
                subCategory: subCategory,
                remark: remark,
                countInBudget: countInBudget
            )
            context.insert(record)
        }

        do {
            try context.save()
            toast.show(isNew ? L10n.Toast.recordAdded : L10n.Toast.recordUpdated)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

#Preview {
    RecordEditorView()
        .modelContainer(for: [RecordItem.self, CategoryItem.self], inMemory: true)
}
