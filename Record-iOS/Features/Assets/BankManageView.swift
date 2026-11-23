import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BankManageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \Bank.order) private var banks: [Bank]
    @Query private var deposits: [DepositRecord]

    @State private var showAdd = false
    @State private var pendingDelete: Bank?
    @State private var orderedBanks: [Bank] = []

    private var displayBanks: [Bank] {
        orderedBanks.isEmpty ? banks : orderedBanks
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(displayBanks) { bank in
                            bankRow(bank)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDelete = bank
                                    } label: {
                                        Label(L10n.Common.delete, systemImage: "trash")
                                    }
                                }
                        }
                        .onMove(perform: moveBanks)
                    } header: {
                        sectionHeader(L10n.Bank.all)
                    }
                }
                .listStyle(.insetGrouped)
                .defaultScrollAnchor(.top)
                .scrollContentBackground(.hidden)
                .background(Theme.background)

                Button {
                    showAdd = true
                } label: {
                    Text(L10n.Bank.addCustom)
                        .font(AppFont.important)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle(L10n.Bank.manage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.large])
        .sheet(isPresented: $showAdd) {
            AddBankView()
        }
        .alert(
            L10n.Common.deleteConfirm,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { bank in
            Button(L10n.Common.cancel, role: .cancel) { pendingDelete = nil }
            Button(L10n.Common.delete, role: .destructive) {
                delete(bank)
                pendingDelete = nil
            }
        } message: { _ in
            Text(L10n.Common.deleteMessage)
        }
        .overlay { ToastHost(topInset: 54) }
        #if DEBUG
        .onAppear {
            if orderedBanks.isEmpty { orderedBanks = banks }
            if CommandLine.arguments.contains("-openAddBank") {
                showAdd = true
            }
        }
        .onChange(of: banks.count) { _, _ in
            orderedBanks = banks
        }
        #endif
    }

    private func bankRow(_ bank: Bank) -> some View {
        HStack(spacing: 10) {
            BankLogo(name: bank.name, icon: bank.icon, colorHex: bank.colorHex, size: 38)

            Text(bank.name)
                .font(AppFont.important)
                .lineLimit(1)
                .minimumScaleFactor(0.88)

            bankTag(for: bank)

            Spacer(minLength: 6)

            Text(L10n.Bank.count(deposits.filter { $0.bankName == bank.name }.count))
                .font(AppFont.secondary)
                .foregroundStyle(Theme.text3)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func bankTag(for bank: Bank) -> some View {
        if isDefaultBank(bank) {
            Text(L10n.Bank.tagDefault)
                .font(AppFont.small)
                .foregroundStyle(Theme.text3)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.track, in: Capsule())
        }
    }

    private func isDefaultBank(_ bank: Bank) -> Bool {
        bank.isSystem
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text3)
            .textCase(nil)
    }

    private func moveBanks(from source: IndexSet, to destination: Int) {
        var ordered = displayBanks
        ordered.move(fromOffsets: source, toOffset: destination)
        orderedBanks = ordered
        if persistOrder() {
            toast.show(L10n.Toast.orderSaved)
        } else {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }

    @discardableResult
    private func persistOrder() -> Bool {
        for (index, bank) in orderedBanks.enumerated() where bank.order != index {
            bank.order = index
        }
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    private func delete(_ bank: Bank) {
        context.delete(bank)
        do {
            try context.save()
            toast.show(L10n.Toast.bankDeleted)
        } catch {
            toast.show(L10n.Toast.deleteFailed, style: .error)
        }
    }
}

private struct AddBankView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \Bank.order) private var banks: [Bank]

    @State private var name = ""
    @State private var icon = ""
    @State private var colorHex = "1B7F79"

    private let colors = ["1B7F79", "00529C", "D7261E", "C8102E", "00703C", "64748B"]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var previewIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(trimmedName.prefix(1)) : String(trimmed.prefix(2))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    groupLabel(L10n.Bank.info)

                    infoCard {
                        fieldRow(L10n.Bank.name) {
                            TextField(L10n.Bank.name, text: $name)
                                .font(AppFont.important)
                                .multilineTextAlignment(.trailing)
                        }

                        fieldDivider

                        fieldRow(L10n.Bank.iconLabel) {
                            TextField(L10n.Bank.iconPlaceholder, text: $icon)
                                .font(AppFont.important)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Text(L10n.Bank.iconHint)
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 2)

                    groupLabel(L10n.Bank.iconColor)

                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hexString: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if colorHex == hex {
                                            Circle()
                                                .stroke(Theme.text, lineWidth: 2)
                                                .padding(-4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }

                    groupLabel(L10n.Bank.preview)

                    HStack(spacing: 12) {
                        BankLogo(
                            name: trimmedName.isEmpty ? L10n.Assets.bankFallback : trimmedName,
                            icon: previewIcon,
                            colorHex: colorHex,
                            size: 42
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(trimmedName.isEmpty ? L10n.Bank.name : trimmedName)
                                .font(AppFont.important)
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Text(L10n.Bank.customSubtitle)
                                .font(AppFont.secondary)
                                .foregroundStyle(Theme.text3)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(L10n.Bank.addCustom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.large])
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.smallMedium)
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
                .font(AppFont.important)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 12)
            content()
        }
        .frame(height: 50)
        .padding(.horizontal, 14)
    }

    private var fieldDivider: some View {
        Divider()
            .overlay(Theme.border)
            .padding(.leading, 14)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let order = (banks.map(\.order).max() ?? -1) + 1
        context.insert(Bank(
            name: trimmedName,
            icon: previewIcon,
            colorHex: colorHex,
            order: order,
            isSystem: false
        ))
        do {
            try context.save()
            toast.show(L10n.Toast.bankAdded)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

#Preview {
    BankManageView()
        .modelContainer(for: [Bank.self, DepositRecord.self], inMemory: true)
}
