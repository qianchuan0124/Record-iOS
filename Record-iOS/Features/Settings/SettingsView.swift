import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query private var categories: [CategoryItem]
    @Query private var records: [RecordItem]
    @AppStorage("record.sync.folderName") private var syncFolderName = ""
    @AppStorage("record.sync.lastBackupText") private var lastBackup = ""
    @AppStorage("record.appearance") private var appearance = "system"
    @State private var showSync = false
    @State private var showData = false
    @State private var showCategories = false
    @State private var showClearDataAlert = false
    @State private var showFeedback = false
    @State private var showAppearance = false
    @State private var didHandleLaunchArgs = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageTitle(text: L10n.Settings.title)
                        .padding(.top, 4)

                    settingsGroup(L10n.Settings.data) {
                        NavigationLink {
                            DataHandleView()
                        } label: {
                            settingsRow(
                                icon: "doc.text",
                                color: "3B82F6",
                                title: L10n.Settings.dataHandle,
                                value: "导出 / 导入"
                            )
                        }
                        .buttonStyle(.plain)

                        rowDivider

                        NavigationLink {
                            SyncSettingsView()
                        } label: {
                            settingsRow(
                                icon: "icloud",
                                color: "10B981",
                                title: L10n.Settings.icloud,
                                value: syncValue
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(L10n.Settings.personalization) {
                        Button {
                            showAppearance = true
                        } label: {
                            settingsRow(
                                icon: "circle.lefthalf.filled",
                                color: "8B5CF6",
                                title: L10n.Settings.appearance,
                                value: appearanceLabel
                            )
                        }
                        .buttonStyle(.plain)

                        rowDivider

                        NavigationLink {
                            CategoryManageView()
                        } label: {
                            settingsRow(
                                icon: "tag",
                                color: "8B5CF6",
                                title: L10n.Settings.customCategories,
                                value: categorySummary
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(L10n.Settings.other) {
                        Button {
                            showFeedback = true
                        } label: {
                            settingsRow(
                                icon: "lightbulb",
                                color: "F59E0B",
                                title: L10n.Settings.feedback,
                                value: version
                            )
                        }
                        .buttonStyle(.plain)

                        rowDivider

                        NavigationLink {
                            AboutView()
                        } label: {
                            settingsRow(
                                icon: "info.circle",
                                color: "94A3B8",
                                title: L10n.Settings.aboutApp,
                                value: ""
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    #if DEBUG
                    settingsGroup(L10n.Settings.developer) {
                        Button(role: .destructive) {
                            showClearDataAlert = true
                        } label: {
                            settingsRow(
                                icon: "trash",
                                color: "E2434F",
                                title: L10n.Settings.clearAll,
                                value: "",
                                showsChevron: false,
                                tint: Theme.expense
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    #endif

                    Text(versionFooter)
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .tint(Theme.brand)
            .navigationDestination(isPresented: $showSync) {
                SyncSettingsView()
            }
            .navigationDestination(isPresented: $showData) {
                DataHandleView()
            }
            .navigationDestination(isPresented: $showCategories) {
                CategoryManageView()
            }
            .sheet(isPresented: $showAppearance) {
                AppearancePickerView(selection: $appearance)
            }
            .alert(L10n.Settings.clearConfirm, isPresented: $showClearDataAlert) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Settings.clear, role: .destructive) { clearAllData() }
            } message: {
                Text(L10n.Settings.clearMessage)
            }
            .alert(L10n.Settings.feedback, isPresented: $showFeedback) {
                Button(L10n.Common.done, role: .cancel) {}
            } message: {
                Text(L10n.Settings.feedbackMessage(version))
            }
            #if DEBUG
            .onAppear {
                guard !didHandleLaunchArgs else { return }
                didHandleLaunchArgs = true
                if CommandLine.arguments.contains("-openSync") { showSync = true }
                if CommandLine.arguments.contains("-openData") { showData = true }
                if CommandLine.arguments.contains("-openCategories") { showCategories = true }
                if CommandLine.arguments.contains("-openAppearance") { showAppearance = true }
            }
            #endif
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.smallMedium)
                .foregroundStyle(Theme.text3)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
        }
    }

    private func settingsRow(
        icon: String,
        color: String,
        title: String,
        value: String,
        showsChevron: Bool = true,
        tint: Color = Theme.text
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hexString: color))
                .frame(width: 29, height: 29)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

            Text(title)
                .font(AppFont.important)
                .foregroundStyle(tint)
                .lineLimit(1)

            Spacer(minLength: 12)

            if !value.isEmpty {
                Text(value)
                    .font(AppFont.secondary)
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.chevron)
            }
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Theme.border)
            .padding(.leading, 55)
    }

    private var syncValue: String {
        if syncFolderName.isEmpty { return L10n.Common.notSet }
        return lastBackup.isEmpty ? syncFolderName : lastBackup
    }

    private var appearanceLabel: String {
        switch appearance {
        case "light": L10n.Settings.light
        case "dark": L10n.Settings.dark
        default: L10n.Settings.followSystem
        }
    }

    private var categorySummary: String {
        let top = categories.filter { $0.parentName == nil }.count
        let children = categories.filter { $0.parentName != nil }.count
        return L10n.Settings.categorySummary(top, children)
    }

    private var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var versionFooter: String {
        L10n.Settings.versionFooter(shortVersion, buildNumber)
    }

    private var version: String {
        "v\(shortVersion)"
    }

    private func clearAllData() {
        do {
            try context.delete(model: RecordItem.self)
            try context.delete(model: DepositRecord.self)
            try context.delete(model: SalaryRecord.self)
            try context.delete(model: AnnualBonus.self)
            try context.delete(model: BudgetItem.self)
            try context.delete(model: CategoryItem.self)
            try context.delete(model: Bank.self)
            try context.save()

            CategorySeed.seedIfNeeded(context, existing: [])
            BankSeed.seedIfNeeded(context, existing: [])
            UserDefaults.standard.set(true, forKey: "record.demo.seeded.v1")
            toast.show(L10n.Toast.dataCleared)
        } catch {
            toast.show(L10n.Toast.deleteFailed, style: .error)
        }
    }

}

private struct AppearancePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    @State private var draft: String

    init(selection: Binding<String>) {
        _selection = selection
        _draft = State(initialValue: selection.wrappedValue)
    }

    private let options: [(id: String, title: String, icon: String)] = [
        ("system", L10n.Settings.followSystem, "circle.lefthalf.filled"),
        ("light", L10n.Settings.light, "sun.max"),
        ("dark", L10n.Settings.dark, "moon")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        Button {
                            draft = option.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.brand)
                                    .frame(width: 26)
                                Text(option.title)
                                    .font(AppFont.important)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                if draft == option.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.brand)
                                }
                            }
                            .frame(height: 54)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)

                        if index < options.count - 1 {
                            Divider()
                                .overlay(Theme.border)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Theme.background)
            .navigationTitle(L10n.Settings.appearance)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) {
                        selection = draft
                        dismiss()
                    }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.height(340)])
    }
}

private struct SyncVersionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let backups: [URL]
    let localRecordCount: Int
    let localCounts: SyncDataCounts
    let onBackup: () -> Void
    let onRestore: (URL) -> Void

    @State private var detailInfo: SyncBackupInfo?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    localCard

                    Text(L10n.Sync.cloudBackups)
                        .font(AppFont.smallMedium)
                        .foregroundStyle(Theme.text3)
                        .padding(.leading, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 0) {
                        if backups.isEmpty {
                            Text(L10n.Sync.noBackups)
                                .font(AppFont.small)
                                .foregroundStyle(Theme.text3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        } else {
                            ForEach(Array(backups.enumerated()), id: \.element) { index, url in
                                let info = SyncFolderService.backupInfo(for: url)
                                HStack(alignment: .top, spacing: 10) {
                                    Button {
                                        detailInfo = info
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: info.isDesktop ? "desktopcomputer" : "iphone")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Theme.brand)
                                                .frame(width: 28, height: 28)
                                                .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Text(info.deviceName)
                                                        .font(AppFont.important)
                                                        .foregroundStyle(Theme.text)
                                                        .lineLimit(1)
                                                    if info.isDesktop {
                                                        Text(L10n.Sync.desktopBadge)
                                                            .font(.system(size: 11, weight: .semibold))
                                                            .foregroundStyle(Theme.brandDark)
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 2)
                                                            .background(Theme.brandSoft, in: Capsule())
                                                    }
                                                }
                                                Text(info.countsText)
                                                    .font(AppFont.secondary)
                                                    .foregroundStyle(Theme.text2)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                Text("\(info.dateText) · \(info.sizeText)")
                                                    .font(AppFont.small)
                                                    .foregroundStyle(Theme.text3)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Spacer(minLength: 6)
                                    Button {
                                        onRestore(url)
                                        dismiss()
                                    } label: {
                                        Text(L10n.Sync.restoreToLocal)
                                            .font(AppFont.smallMedium)
                                            .foregroundStyle(Theme.brand)
                                            .padding(.horizontal, 10)
                                            .frame(height: 32)
                                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                    .stroke(Theme.border, lineWidth: 1)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(14)

                                if index < backups.count - 1 {
                                    Divider()
                                        .overlay(Theme.border)
                                        .padding(.leading, 14)
                                }
                            }
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                .scrollIndicators(.visible)
                .defaultScrollAnchor(.top)
                .frame(maxHeight: .infinity)

                Text(L10n.Sync.versionNote)
                    .font(AppFont.small)
                    .foregroundStyle(Theme.text3)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle(L10n.Sync.versionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.large])
        .sheet(item: $detailInfo) { info in
            SyncBackupDetailView(info: info, local: localCounts)
        }
        #if DEBUG
        .onAppear {
            if CommandLine.arguments.contains("-openBackupDetail"),
               let first = backups.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    detailInfo = SyncFolderService.backupInfo(for: first)
                }
            }
        }
        #endif
    }

    private var localCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.brandGradient)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "iphone")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Sync.localData)
                        .font(AppFont.important)
                        .foregroundStyle(Theme.text)
                    Text(localCounts.text)
                        .font(AppFont.secondary)
                        .foregroundStyle(Theme.text3)
                        .lineLimit(2)
                }

                Spacer()

                Text(L10n.Sync.currentTag)
                    .font(AppFont.small)
                    .foregroundStyle(Theme.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.brandSoft, in: Capsule())
            }

            Button {
                onBackup()
                dismiss()
            } label: {
                Text(L10n.Sync.uploadLocal)
                    .font(AppFont.important)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.summaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.summaryBorder, lineWidth: 1)
        }
    }

}

private struct SyncBackupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let info: SyncBackupInfo
    let local: SyncDataCounts

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    infoCard
                    compareCard
                    Text(L10n.Sync.compareNote)
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle(L10n.Sync.versionDetail)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
        }
        .tint(Theme.brand)
        .presentationDetents([.height(480), .large])
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: info.isDesktop ? "desktopcomputer" : "iphone")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 34, height: 34)
                    .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(info.deviceName)
                            .font(AppFont.important)
                        if info.isDesktop {
                            Text(L10n.Sync.desktopBadge)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.brandDark)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.brandSoft, in: Capsule())
                        }
                    }
                    Text("\(info.dateText) · \(info.sizeText)")
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                }
                Spacer()
            }

            Text(info.countsText)
                .font(AppFont.secondary)
                .foregroundStyle(Theme.text2)
        }
        .padding(14)
        .background(Theme.summaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.summaryBorder, lineWidth: 1)
        }
    }

    private var compareCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.Sync.compareItem)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.Sync.compareLocal)
                    .frame(width: 44, alignment: .trailing)
                Text(L10n.Sync.compareThis)
                    .frame(width: 54, alignment: .trailing)
                Text(L10n.Sync.compareDelta)
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.text3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.leading, 14)

            compareRow(L10n.Sync.compareRecords, local: local.records, remote: info.records)
            Divider().padding(.leading, 14)
            compareRow(L10n.Sync.compareDeposits, local: local.deposits, remote: info.deposits)
            Divider().padding(.leading, 14)
            compareRow(L10n.Sync.comparePayroll, local: local.payroll, remote: info.payroll)
            Divider().padding(.leading, 14)
            compareRow(L10n.Sync.compareBudgets, local: local.budgets, remote: info.budgets)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func compareRow(_ title: String, local: Int, remote: Int) -> some View {
        let delta = remote - local
        let deltaColor: Color = delta == 0 ? Theme.text3 : (delta > 0 ? Theme.income : Theme.expense)
        return HStack(spacing: 8) {
            Text(title)
                .font(AppFont.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(local)")
                .font(AppFont.secondary)
                .foregroundStyle(Theme.text2)
                .frame(width: 44, alignment: .trailing)
            Text("\(remote)")
                .font(AppFont.secondary)
                .foregroundStyle(Theme.text)
                .frame(width: 54, alignment: .trailing)
            Text(delta == 0 ? "—" : (delta > 0 ? "+\(delta)" : "\(delta)"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(deltaColor)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(delta == 0 ? Color.clear : (delta > 0 ? Theme.income.opacity(0.07) : Theme.expense.opacity(0.07)))
        }
    }
}

private struct SyncNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var confirmLabel: String?
    var destructive = true
    var confirmAction: (() -> Void)?
    var cancelLabel = L10n.Common.cancel
    var cancelAction: (() -> Void)?
}

private struct SyncSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [RecordItem]
    @Query private var deposits: [DepositRecord]
    @Query private var salaries: [SalaryRecord]
    @Query private var bonuses: [AnnualBonus]
    @Query private var budgets: [BudgetItem]
    @AppStorage("record.sync.folderName") private var folderName = ""
    @AppStorage("record.sync.autoBackup") private var autoBackup = false
    @AppStorage("record.sync.lastBackupText") private var lastBackup = ""
    @State private var showPicker = false
    @State private var showVersionPicker = false
    @State private var backups: [URL] = []
    @State private var pendingRestore: URL?
    @State private var pendingBackupAfterSheet = false
    @State private var notice: SyncNotice?
    @State private var workingText = ""
    @State private var showClearFolderConfirm = false

    private var isWorking: Bool { !workingText.isEmpty }

    private var localCounts: SyncDataCounts {
        SyncDataCounts(
            records: records.count,
            deposits: deposits.count,
            payroll: salaries.count + bonuses.count,
            budgets: budgets.count
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                folderCard

                statusGroup

                Text(L10n.Sync.backupHint)
                    .font(AppFont.small)
                    .foregroundStyle(Theme.text3)
                    .padding(.horizontal, 2)

                VStack(spacing: 10) {
                    Button {
                        openRestore()
                    } label: {
                        Label(L10n.Sync.syncNow, systemImage: "arrow.triangle.2.circlepath")
                            .font(AppFont.important)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .opacity(folderName.isEmpty ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(folderName.isEmpty || isWorking)

                    Button {
                        showPicker = true
                    } label: {
                        Text(L10n.Sync.changeFolder)
                            .font(AppFont.important)
                            .foregroundStyle(Theme.brand)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.brandBorder, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)

                    if !folderName.isEmpty {
                        Button(role: .destructive) {
                            showClearFolderConfirm = true
                        } label: {
                            Text(L10n.Sync.clearFolder)
                                .font(AppFont.important)
                                .foregroundStyle(Theme.expense)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.expense.opacity(0.35), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 100)
        }
        .scrollBounceBehavior(.always)
        .scrollIndicators(.visible)
        .background(Theme.background)
        .pushedPageChrome(title: L10n.Sync.title)
        .tint(Theme.brand)
        .disabled(isWorking)
        .alert(L10n.Common.deleteConfirm, isPresented: $showClearFolderConfirm) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.delete, role: .destructive) {
                SyncFolderService.clearFolder()
                folderName = ""
                autoBackup = false
                backups = []
            }
        } message: {
            Text(L10n.Common.deleteMessage)
        }
        .overlay {
            if isWorking {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(workingText)
                            .font(AppFont.secondaryMedium)
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isWorking)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    try SyncFolderService.saveFolder(url)
                    folderName = url.lastPathComponent
                    backups = SyncFolderService.listBackups()
                } catch {
                    notice = SyncNotice(title: L10n.Sync.folderFailed, message: error.localizedDescription)
                }
            case .failure(let error):
                notice = SyncNotice(title: L10n.Sync.folderFailed, message: error.localizedDescription)
            }
        }
        .sheet(isPresented: $showVersionPicker, onDismiss: {
            if pendingBackupAfterSheet {
                pendingBackupAfterSheet = false
                backup()
            } else if let url = pendingRestore, !isWorking {
                notice = confirmNotice(for: url)
            }
        }) {
            SyncVersionPickerView(
                backups: backups,
                localRecordCount: records.count,
                localCounts: localCounts,
                onBackup: {
                    pendingBackupAfterSheet = true
                },
                onRestore: { url in
                    pendingRestore = url
                }
            )
        }
        .alert(item: $notice) { notice in
            alert(for: notice)
        }
        .onAppear {
            backups = SyncFolderService.listBackups()
            #if DEBUG
            if CommandLine.arguments.contains("-seedSyncBackups") {
                seedSyncBackups()
            }
            if CommandLine.arguments.contains("-openSyncPicker") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showVersionPicker = true
                }
            }
            if CommandLine.arguments.contains("-useLocalFolder"),
               let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? SyncFolderService.saveFolder(url)
                folderName = url.lastPathComponent
                backups = SyncFolderService.listBackups()
            }
            if CommandLine.arguments.contains("-doBackup") {
                backup()
            }
            if CommandLine.arguments.contains("-doRestore"),
               let url = SyncFolderService.listBackups().first {
                pendingRestore = url
                restore(url)
            }
            #endif
        }
    }

    private var folderCard: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(hexString: "10B981"))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "icloud")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.Sync.icloudDrive)
                        .font(AppFont.important)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(folderSubtitle)
                        .font(AppFont.secondary)
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.chevron)
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var statusGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Sync.status)
                .font(AppFont.smallMedium)
                .foregroundStyle(Theme.text3)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                syncRow(L10n.Sync.localRecords, L10n.Sync.recordCount(records.count))
                syncDivider
                syncRow(L10n.Sync.cloudBackups, L10n.Sync.backupCount(backups.count))
                syncDivider
                syncRow(L10n.Sync.lastBackup, lastBackup.isEmpty ? L10n.Common.none : lastBackup)
                syncDivider

                Toggle(L10n.Sync.autoBackup, isOn: $autoBackup)
                    .font(AppFont.important)
                    .tint(Theme.brand)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .disabled(folderName.isEmpty)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
        }
    }

    private var folderSubtitle: String {
        if folderName.isEmpty { return L10n.Sync.noFolder }
        if lastBackup.isEmpty { return "\(folderName) · \(L10n.Sync.folderSelected)" }
        return "\(folderName) · \(L10n.Sync.syncedAt(lastBackup))"
    }

    private func syncRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppFont.important)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 12)
            Text(value)
                .font(AppFont.secondary)
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
    }

    private var syncDivider: some View {
        Divider()
            .overlay(Theme.border)
            .padding(.leading, 14)
    }

    #if DEBUG
    private func seedSyncBackups() {
        guard let latest = SyncFolderService.listBackups().first,
              let folder = SyncFolderService.resolveFolder(),
              let data = try? Data(contentsOf: latest)
        else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let calendar = Calendar.current
        let now = Date()

        for offset in 2...8 {
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let url = folder.appendingPathComponent("record-backup-\(formatter.string(from: date)).json")
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        backups = SyncFolderService.listBackups()
    }
    #endif

    private func openRestore() {
        do {
            backups = try SyncFolderService.loadBackups()
            pendingRestore = nil
            pendingBackupAfterSheet = false
            showVersionPicker = true
        } catch {
            notice = SyncNotice(
                title: L10n.Sync.accessLostTitle,
                message: L10n.Sync.accessLost,
                confirmLabel: L10n.Sync.chooseAgain,
                destructive: false,
                confirmAction: { showPicker = true }
            )
        }
    }

    private func confirmNotice(for url: URL) -> SyncNotice {
        SyncNotice(
            title: L10n.Sync.confirmRestoreTitle,
            message: L10n.Sync.confirmRestoreMessage(SyncFolderService.displayName(for: url)),
            confirmLabel: L10n.Sync.overwriteAction,
            confirmAction: { restore(url) },
            cancelAction: { pendingRestore = nil }
        )
    }

    private func alert(for notice: SyncNotice) -> Alert {
        if let confirmLabel = notice.confirmLabel {
            let primary: Alert.Button = notice.destructive
                ? .destructive(Text(confirmLabel), action: { notice.confirmAction?() })
                : .default(Text(confirmLabel), action: { notice.confirmAction?() })
            return Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                primaryButton: primary,
                secondaryButton: .cancel(Text(notice.cancelLabel), action: { notice.cancelAction?() })
            )
        }
        return Alert(
            title: Text(notice.title),
            message: Text(notice.message),
            dismissButton: .default(Text(L10n.Sync.gotIt), action: { notice.cancelAction?() })
        )
    }

    private func backup() {
        guard !isWorking else { return }
        workingText = L10n.Sync.backingUp
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            do {
                try SyncFolderService.writeBackup(context: context)
                lastBackup = UserDefaults.standard.string(forKey: "record.sync.lastBackupText") ?? ""
                backups = SyncFolderService.listBackups()
                workingText = ""
                notice = SyncNotice(title: L10n.Sync.backupSuccess, message: L10n.Sync.backupSuccessMessage)
            } catch {
                workingText = ""
                notice = SyncNotice(title: L10n.Sync.backupFailed, message: backupMessage(error))
            }
        }
    }

    private func restore(_ url: URL) {
        guard !isWorking else { return }
        workingText = L10n.Sync.restoring
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            do {
                try SyncFolderService.restore(from: url, context: context)
                lastBackup = UserDefaults.standard.string(forKey: "record.sync.lastBackupText") ?? ""
                backups = SyncFolderService.listBackups()
                let summary = restoreSummary()
                workingText = ""
                pendingRestore = nil
                notice = SyncNotice(title: L10n.Sync.restoreSuccess, message: summary)
            } catch {
                workingText = ""
                notice = SyncNotice(title: L10n.Sync.restoreFailed, message: restoreMessage(error))
            }
        }
    }

    private func restoreSummary() -> String {
        let recordCount = (try? context.fetchCount(FetchDescriptor<RecordItem>())) ?? 0
        let depositCount = (try? context.fetchCount(FetchDescriptor<DepositRecord>())) ?? 0
        let salaryCount = (try? context.fetchCount(FetchDescriptor<SalaryRecord>())) ?? 0
        let bonusCount = (try? context.fetchCount(FetchDescriptor<AnnualBonus>())) ?? 0
        let budgetCount = (try? context.fetchCount(FetchDescriptor<BudgetItem>())) ?? 0
        return L10n.Sync.restoreSummary(recordCount, depositCount, salaryCount + bonusCount, budgetCount)
    }

    private func restoreMessage(_ error: Error) -> String {
        if let sync = error as? SyncError, let message = sync.errorDescription { return message }
        if error is DecodingError { return L10n.Sync.badBackup }
        if (error as NSError).domain == NSCocoaErrorDomain { return L10n.Sync.readBackupFailed }
        return L10n.Sync.restoreFailedMessage
    }

    private func backupMessage(_ error: Error) -> String {
        if let sync = error as? SyncError, let message = sync.errorDescription { return message }
        return L10n.Sync.backupFailedMessage
    }
}

private struct BackupListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let backups: [URL]
    let onSelect: (URL) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if backups.isEmpty {
                    EmptyHint(text: L10n.Sync.noBackups)
                } else {
                    List(backups, id: \.self) { url in
                        Button {
                            onSelect(url)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(SyncFolderService.displayName(for: url))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                    Text(sizeText(url))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.text3)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.chevron)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Sync.chooseBackup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .tint(Theme.brand)
        }
    }

    private func sizeText(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

private struct DataHandleView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \RecordItem.date, order: .reverse) private var records: [RecordItem]
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]
    @Query(sort: \Bank.order) private var banks: [Bank]
    @Query(sort: \BudgetItem.name) private var budgets: [BudgetItem]
    @Query(sort: \SalaryRecord.date) private var salaries: [SalaryRecord]
    @Query(sort: \AnnualBonus.date) private var bonuses: [AnnualBonus]
    @Query(sort: \DepositRecord.order) private var deposits: [DepositRecord]
    @State private var exportDocument = ExcelExportDocument()
    @State private var showExporter = false
    @State private var pendingExcelPayload: ExcelImportPayload?
    @State private var excelPreviewText = ""
    @State private var showExcelPreview = false
    @State private var showImport = false
    @State private var importSummary = ""
    @State private var importFailures: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                dataCard(
                    icon: "square.and.arrow.up",
                    color: "3B82F6",
                    title: L10n.Data.exportTitle,
                    desc: L10n.Data.exportDesc
                ) {
                    Button {
                        guard let data = makeXLSX() else {
                            toast.show(L10n.Toast.exportFailed, style: .error)
                            return
                        }
                        exportDocument = ExcelExportDocument(data: data)
                        showExporter = true
                    } label: {
                        Text(L10n.Data.exportAll(records.count))
                            .font(AppFont.important)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text(L10n.Data.exportSheets)
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                dataCard(
                    icon: "square.and.arrow.down",
                    color: "10B981",
                    title: L10n.Data.importTitleCard,
                    desc: L10n.Data.importDesc
                ) {
                    Button {
                        showImport = true
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(Theme.text3)
                            Text(L10n.Data.chooseFile)
                                .font(AppFont.important)
                                .foregroundStyle(Theme.text)
                            Text(L10n.Data.importHint)
                                .font(AppFont.small)
                                .foregroundStyle(Theme.text3)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 12)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.text3.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !importSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Data.recentImport)
                            .font(AppFont.smallMedium)
                            .foregroundStyle(Theme.text3)
                            .padding(.leading, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(importSummary)
                                .font(AppFont.important)
                                .foregroundStyle(Theme.text)

                            if !importFailures.isEmpty {
                                Text(L10n.Data.viewFailures)
                                    .font(AppFont.small)
                                    .foregroundStyle(Theme.text3)
                                ForEach(importFailures.prefix(5), id: \.self) { item in
                                    Text(item)
                                        .font(AppFont.small)
                                        .foregroundStyle(Theme.expense)
                                }
                                if importFailures.count > 5 {
                                    Text(L10n.Data.moreFailures(importFailures.count - 5))
                                        .font(AppFont.small)
                                        .foregroundStyle(Theme.text3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        }
                    }
                }

                Text(L10n.Data.totalRecords(records.count))
                    .font(AppFont.small)
                    .foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollBounceBehavior(.always)
        .scrollIndicators(.visible)
        .background(Theme.background)
        .pushedPageChrome(title: L10n.Data.title)
        .tint(Theme.brand)
        .fileImporter(
            isPresented: $showImport,
            allowedContentTypes: [.commaSeparatedText, .plainText, ExcelExportDocument.contentType]
        ) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure(let error):
                importSummary = L10n.Data.importFailed
                importFailures = [error.localizedDescription]
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: ExcelExportDocument.contentType,
            defaultFilename: "记账清单-\(DateText.shortFormatter.string(from: Date()))"
        ) { result in
            switch result {
            case .success:
                toast.show(L10n.Toast.exportSaved)
            case .failure(let error):
                if (error as NSError).code == NSUserCancelledError { return }
                toast.show(L10n.Toast.exportFailed, style: .error)
            }
        }
        .alert(L10n.Data.excelPreviewTitle, isPresented: $showExcelPreview) {
            Button(L10n.Common.cancel, role: .cancel) {
                pendingExcelPayload = nil
            }
            Button(L10n.Data.excelMerge) {
                applyExcelImport(mode: .merge)
            }
            Button(L10n.Data.excelReplace, role: .destructive) {
                applyExcelImport(mode: .replace)
            }
        } message: {
            Text(excelPreviewText)
        }
        #if DEBUG
        .onAppear {
            guard let index = CommandLine.arguments.firstIndex(of: "-excelImportPath"),
                  CommandLine.arguments.indices.contains(index + 1) else { return }
            let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                importFile(url)
            }
        }
        #endif
    }

    private func dataCard<Content: View>(
        icon: String,
        color: String,
        title: String,
        desc: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(hexString: color))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppFont.important)
                        .foregroundStyle(Theme.text)
                    Text(desc)
                        .font(AppFont.secondary)
                        .foregroundStyle(Theme.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func importFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        if url.pathExtension.lowercased() == "xlsx" {
            guard let data = try? Data(contentsOf: url) else {
                importSummary = L10n.Data.importFailed
                importFailures = [L10n.Data.readFailed]
                toast.show(L10n.Toast.importFailed, style: .error)
                return
            }
            do {
                let sheets = try XLSXReader.sheets(from: data)
                let payload = ExcelImportParser.payload(from: sheets)
                guard !payload.isEmpty else {
                    importSummary = L10n.Data.importFailed
                    importFailures = [L10n.Data.excelNoSheets]
                    toast.show(L10n.Toast.importFailed, style: .error)
                    return
                }
                pendingExcelPayload = payload
                #if DEBUG
                if let index = CommandLine.arguments.firstIndex(of: "-excelImportMode"),
                   CommandLine.arguments.indices.contains(index + 1) {
                    applyExcelImport(mode: CommandLine.arguments[index + 1] == "replace" ? .replace : .merge)
                    return
                }
                #endif
                excelPreviewText = L10n.Data.excelPreviewMessage(
                    payload.countItems
                        .map { L10n.Data.excelSheetCount($0.name, $0.count) }
                        .joined(separator: " · ")
                )
                showExcelPreview = true
            } catch {
                importSummary = L10n.Data.importFailed
                importFailures = [L10n.Data.excelReadFailed]
                toast.show(L10n.Toast.importFailed, style: .error)
            }
            return
        }

        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: gb18030) else {
            importSummary = L10n.Data.importFailed
            importFailures = [L10n.Data.readFailed]
            toast.show(L10n.Toast.importFailed, style: .error)
            return
        }

        let rows = parseCSV(text)
        guard rows.count > 1 else {
            importSummary = L10n.Data.importFailed
            importFailures = [L10n.Data.noData]
            toast.show(L10n.Toast.importFailed, style: .error)
            return
        }

        let header = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        func index(_ name: String) -> Int? { header.firstIndex(of: name) }

        guard let dateIndex = index("日期"), let typeIndex = index("类型"),
              let categoryIndex = index("分类"), let subIndex = index("子分类"),
              let amountIndex = index("金额") else {
            importSummary = L10n.Data.importFailed
            importFailures = [L10n.Data.missingColumns]
            toast.show(L10n.Toast.importFailed, style: .error)
            return
        }
        let remarkIndex = index("备注")
        let budgetIndex = index("计入预算")

        let formatters: [DateFormatter] = {
            ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyy/M/d", "yyyy/MM/dd"].map { format in
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = format
                return f
            }
        }()

        func dateValue(_ text: String) -> Date? {
            if let serial = Double(text),
               serial >= 1,
               serial < 100_000,
               !text.contains("-"),
               !text.contains("/") {
                let date = Date(timeIntervalSince1970: (serial - 25_569) * 86_400)
                return Calendar.current.startOfDay(for: date)
            }
            return formatters.compactMap { $0.date(from: text) }.first
        }

        var success = 0
        var failures: [String] = []

        for (offset, row) in rows.dropFirst().enumerated() {
            let line = offset + 2
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }

            func value(_ index: Int?) -> String {
                guard let index, row.indices.contains(index) else { return "" }
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let dateText = value(dateIndex)
            let typeText = value(typeIndex)
            let category = value(categoryIndex)
            let subCategory = value(subIndex)
            let amountText = value(amountIndex)

            guard let date = dateValue(dateText) else {
                failures.append(L10n.Data.lineDateError(line))
                continue
            }
            guard let amount = Double(amountText.replacingOccurrences(of: ",", with: "")), amount > 0 else {
                failures.append(L10n.Data.lineAmountError(line))
                continue
            }
            let type: RecordType
            if typeText == "支出" { type = .expense }
            else if typeText == "收入" { type = .income }
            else {
                failures.append(L10n.Data.lineTypeError(line))
                continue
            }
            guard !category.isEmpty, !subCategory.isEmpty else {
                failures.append(L10n.Data.lineCategoryError(line))
                continue
            }

            context.insert(RecordItem(
                date: date,
                amount: (amount * 100).rounded() / 100,
                type: type,
                category: category,
                subCategory: subCategory,
                remark: value(remarkIndex),
                countInBudget: value(budgetIndex) != "否"
            ))
            success += 1
        }

        do {
            try context.save()
        } catch {
            importSummary = L10n.Data.importFailed
            importFailures = [L10n.Data.importFailedMessage]
            toast.show(L10n.Toast.importFailed, style: .error)
            return
        }
        importSummary = L10n.Data.importResult(success, failures.count)
        importFailures = failures
        if failures.isEmpty {
            toast.show(L10n.Toast.importDone(success))
        } else {
            toast.show(L10n.Data.importResult(success, failures.count), style: .error)
        }
    }

    private func applyExcelImport(mode: ExcelImportMode) {
        guard let payload = pendingExcelPayload else { return }

        do {
            if mode == .replace {
                clearExcelImportedData(payload)
            }

            for item in payload.records {
                context.insert(RecordItem(
                    date: item.date,
                    amount: item.amount,
                    type: item.type,
                    category: item.category,
                    subCategory: item.subCategory,
                    remark: item.remark,
                    countInBudget: item.countInBudget
                ))
            }

            var budgetByName: [String: BudgetItem] = mode == .merge
                ? Dictionary(budgets.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
                : [:]
            for item in payload.budgets {
                if let existing = budgetByName[item.name] {
                    existing.amount = item.amount
                } else {
                    let budget = BudgetItem(name: item.name, amount: item.amount)
                    context.insert(budget)
                    budgetByName[item.name] = budget
                }
            }

            for item in payload.salaries {
                context.insert(SalaryRecord(
                    date: item.date,
                    baseSalary: item.baseSalary,
                    overtimePay: item.overtimePay,
                    oneTimeBonus: item.oneTimeBonus,
                    socialInsurance: item.socialInsurance,
                    tax: item.tax,
                    taxRate: item.taxRate
                ))
            }

            for item in payload.bonuses {
                context.insert(AnnualBonus(
                    date: item.date,
                    bonus: item.bonus,
                    tax: item.tax,
                    taxRate: item.taxRate
                ))
            }

            var depositOrder = mode == .merge ? (deposits.map(\.order).max() ?? -1) : -1
            for item in payload.deposits {
                depositOrder += 1
                context.insert(DepositRecord(
                    bankName: item.bankName,
                    amount: item.amount,
                    startDate: item.startDate,
                    years: item.years,
                    rate: item.rate,
                    interest: item.interest,
                    order: depositOrder
                ))
            }

            var bankByName: [String: Bank] = mode == .merge
                ? Dictionary(banks.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
                : [:]
            for item in payload.banks {
                if let existing = bankByName[item.name] {
                    existing.icon = item.icon
                    existing.colorHex = item.colorHex
                    existing.order = item.order
                    existing.isSystem = item.isSystem
                } else {
                    let bank = Bank(
                        name: item.name,
                        icon: item.icon,
                        colorHex: item.colorHex,
                        order: item.order,
                        isSystem: item.isSystem
                    )
                    context.insert(bank)
                    bankByName[item.name] = bank
                }
            }

            var categoryByKey: [String: CategoryItem] = mode == .merge
                ? Dictionary(categories.map {
                    (categoryKey(name: $0.name, parentName: $0.parentName), $0)
                }, uniquingKeysWith: { first, _ in first })
                : [:]
            for item in payload.categories {
                let key = categoryKey(name: item.name, parentName: item.parentName)
                if let existing = categoryByKey[key] {
                    existing.icon = item.icon
                    existing.colorHex = item.colorHex
                    existing.order = item.order
                    existing.isArchived = item.isArchived
                    existing.isSystem = item.isSystem
                } else {
                    let category = CategoryItem(
                        name: item.name,
                        icon: item.icon,
                        colorHex: item.colorHex,
                        order: item.order,
                        parentName: item.parentName,
                        isArchived: item.isArchived,
                        isSystem: item.isSystem
                    )
                    context.insert(category)
                    categoryByKey[key] = category
                }
            }

            try context.save()
            applyExcelSettings(payload)

            var summary = L10n.Data.excelImportResult(
                payload.records.count,
                payload.salaries.count,
                payload.bonuses.count,
                payload.deposits.count,
                payload.budgets.count,
                payload.categories.count,
                payload.banks.count
            )
            if payload.presentSheets.contains("设置") {
                summary += "\n" + L10n.Data.excelSettingsUpdated
            }
            importSummary = summary
            importFailures = []
            pendingExcelPayload = nil
            toast.show(L10n.Data.excelImportDone)
        } catch {
            context.rollback()
            importSummary = L10n.Data.importFailed
            importFailures = [L10n.Data.importFailedMessage]
            pendingExcelPayload = nil
            toast.show(L10n.Toast.importFailed, style: .error)
        }
    }

    private func clearExcelImportedData(_ payload: ExcelImportPayload) {
        if payload.presentSheets.contains("账单") {
            records.forEach(context.delete)
        }
        if payload.presentSheets.contains("预算") {
            budgets.forEach(context.delete)
        }
        if payload.presentSheets.contains("工资") {
            salaries.forEach(context.delete)
        }
        if payload.presentSheets.contains("年终奖") {
            bonuses.forEach(context.delete)
        }
        if payload.presentSheets.contains("存款") {
            deposits.forEach(context.delete)
        }
        if payload.presentSheets.contains("银行") {
            banks.forEach(context.delete)
        }
        if payload.presentSheets.contains("分类") {
            categories.forEach(context.delete)
        }
    }

    private func applyExcelSettings(_ payload: ExcelImportPayload) {
        if let mode = payload.taxMonthMode {
            var preferences = PayrollPreferences.load()
            preferences.salaryTaxMonthMode = mode
            preferences.save()
        }

        guard payload.budgetCycleEnabled != nil ||
              payload.budgetStartDay != nil ||
              payload.budgetEndDay != nil ||
              payload.budgetIncomeMode != nil else { return }

        var preferences = BudgetPreferences.load()
        if let enabled = payload.budgetCycleEnabled {
            preferences.cycleEnabled = enabled
        }
        if let startDay = payload.budgetStartDay {
            preferences.startDay = startDay
        }
        if let endDay = payload.budgetEndDay {
            preferences.endDay = endDay
        }
        if let incomeMode = payload.budgetIncomeMode {
            preferences.incomeMode = incomeMode
        }
        preferences.save()
    }

    private func categoryKey(name: String, parentName: String?) -> String {
        "\(name)\u{1F}\(parentName ?? "")"
    }

    private func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()

        while let char = iterator.next() {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                row.append(field)
                field = ""
            } else if (char == "\n" || char == "\r") && !inQuotes {
                if char == "\r", let peek = iterator.next(), peek != "\n" {
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                    continue
                }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(char)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private func makeXLSX() -> Data? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        func date(_ value: Date) -> XLSXCell { .text(formatter.string(from: value)) }
        func text(_ value: String) -> XLSXCell { .text(value) }
        func number(_ value: Double) -> XLSXCell { .number(value) }
        func integer(_ value: Int) -> XLSXCell { .integer(value) }

        var sheets: [XLSXSheet] = []

        sheets.append(XLSXSheet(name: "账单", rows: [
            [text("日期"), text("类型"), text("分类"), text("子分类"), text("金额"), text("备注"), text("计入预算"), text("创建时间")]
        ] + records.map { item in
            [
                date(item.date),
                text(item.type.dataTitle),
                text(item.category),
                text(item.subCategory),
                number(item.amount),
                text(item.remark),
                text(item.countInBudget ? "是" : "否"),
                date(item.createdAt)
            ]
        }))

        sheets.append(XLSXSheet(name: "预算", rows: [
            [text("预算名称"), text("预算金额")]
        ] + budgets.map { item in
            [text(item.name), number(item.amount)]
        }))

        sheets.append(XLSXSheet(name: "工资", rows: [
            [text("日期"), text("基本工资"), text("加班费"), text("一次性奖金"), text("五险一金"), text("税前"), text("税率(%)"), text("税额"), text("实际到手")]
        ] + salaries.map { item in
            [
                date(item.date),
                number(item.baseSalary),
                number(item.overtimePay),
                number(item.oneTimeBonus),
                number(item.socialInsurance),
                number(item.gross),
                number(item.taxRate),
                number(item.tax),
                number(item.netPay)
            ]
        }))

        sheets.append(XLSXSheet(name: "年终奖", rows: [
            [text("日期"), text("奖金"), text("税率(%)"), text("税额"), text("实际到手")]
        ] + bonuses.map { item in
            [
                date(item.date),
                number(item.bonus),
                number(item.taxRate),
                number(item.tax),
                number(item.netPay)
            ]
        }))

        sheets.append(XLSXSheet(name: "存款", rows: [
            [text("银行"), text("金额"), text("存款时间"), text("年限"), text("利率(%)"), text("利息"), text("到期时间")]
        ] + deposits.map { item in
            [
                text(item.bankName),
                number(item.amount),
                date(item.startDate),
                number(item.years),
                number(item.rate),
                number(item.interest),
                date(item.maturityDate)
            ]
        }))

        sheets.append(XLSXSheet(name: "银行", rows: [
            [text("名称"), text("图标"), text("颜色"), text("排序"), text("类型")]
        ] + banks.map { item in
            [
                text(item.name),
                text(item.icon),
                text(item.colorHex),
                integer(item.order),
                text(item.isSystem ? "内置" : "自定义")
            ]
        }))

        sheets.append(XLSXSheet(name: "分类", rows: [
            [text("名称"), text("父分类"), text("图标"), text("颜色"), text("排序"), text("归档"), text("系统分类")]
        ] + categories.map { item in
            [
                text(item.name),
                text(item.parentName ?? ""),
                text(item.icon),
                text(item.colorHex),
                integer(item.order),
                text(item.isArchived ? "是" : "否"),
                text(item.isSystem ? "是" : "否")
            ]
        }))

        let payroll = PayrollPreferences.load()
        let budget = BudgetPreferences.load()
        sheets.append(XLSXSheet(name: "设置", rows: [
            [text("设置项"), text("值")],
            [text("导出时间"), date(Date())],
            [text("算税月份"), text(payroll.salaryTaxMonthMode.title)],
            [text("预算周期"), text(budget.cycleEnabled ? "\(budget.startDay) 日至 \(budget.endDay) 日" : "自然月")],
            [text("收入计算"), text(budget.incomeMode.title)]
        ]))

        return XLSXWorkbook.make(sheets: sheets)
    }
}

private struct ExcelExportDocument: FileDocument {
    static let contentType = UTType(filenameExtension: "xlsx") ?? .data

    static var readableContentTypes: [UTType] { [contentType] }
    static var writableContentTypes: [UTType] { [contentType] }

    var data = Data()

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct CategoryManageView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]
    @Query private var records: [RecordItem]
    @State private var showAdd = false

    private var topLevel: [CategoryItem] {
        categories.filter { $0.parentName == nil }
    }

    @State private var expanded: Set<String> = []
    @State private var didExpandFirst = false
    @State private var addChildParent: CategoryItem?
    @State private var deleteTarget: CategoryItem?

    var body: some View {
        List {
            Section {
                Text(L10n.Settings.categoryManagerHint)
                    .font(AppFont.small)
                    .foregroundStyle(Theme.text3)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 8, trailing: 18))
            }

            ForEach(topLevel) { item in
                categoryCard(item)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTarget = item
                        } label: {
                            Label(L10n.Common.delete, systemImage: "archivebox")
                        }
                    }
            }
            .onMove(perform: moveTop)

            Section {
                Button {
                    restoreDefaults()
                } label: {
                    Text(L10n.Settings.restoreDefaults)
                        .font(AppFont.important)
                        .foregroundStyle(Theme.brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.brandBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))

                Color.clear
                    .frame(height: 42)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listSectionSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .pushedPageChrome(title: L10n.Settings.customCategories) {
            EditButton()
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .sheet(isPresented: $showAdd) {
            AddCategoryView()
        }
        .sheet(item: $addChildParent) { parent in
            AddCategoryView(parent: parent)
        }
        .sheet(item: $deleteTarget) { item in
            DeleteCategoryView(item: item)
        }
        .onAppear {
            guard !didExpandFirst else { return }
            didExpandFirst = true
            if let first = topLevel.first { expanded.insert(first.name) }
            #if DEBUG
            if CommandLine.arguments.contains("-openDeleteCategory") {
                deleteTarget = topLevel.first
            }
            #endif
        }
    }

    private func categoryCard(_ item: CategoryItem) -> some View {
        let children = categories.filter { $0.parentName == item.name && !$0.isArchived }
        let isExpanded = expanded.contains(item.name)

        return VStack(spacing: 0) {
            Button {
                if isExpanded { expanded.remove(item.name) }
                else { expanded.insert(item.name) }
            } label: {
                HStack(spacing: 10) {
                    CategoryBadge(icon: item.icon, colorHex: item.colorHex, size: 30)

                    Text(item.name)
                        .font(AppFont.important)
                        .foregroundStyle(Theme.text)

                    Spacer(minLength: 8)

                    Text(L10n.Settings.childrenCount(children.count))
                        .font(AppFont.secondary)
                        .foregroundStyle(Theme.text3)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.chevron)
                }
                .frame(minHeight: 50)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .overlay(Theme.border)
                    .padding(.leading, 14)

                if children.isEmpty {
                    Text(L10n.Settings.newUnder(item.name))
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 46)
                        .padding(.vertical, 12)
                } else {
                    ForEach(children) { child in
                        HStack(spacing: 8) {
                            Text(child.name)
                                .font(AppFont.secondary)
                                .foregroundStyle(Theme.text)
                            Spacer()
                            if child.isSystem {
                                Text(L10n.Common.system)
                                    .font(AppFont.small)
                                    .foregroundStyle(Theme.text3)
                            }
                        }
                        .frame(height: 42)
                        .padding(.leading, 46)
                        .padding(.trailing, 14)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteTarget = child
                            } label: {
                                Label(L10n.Common.delete, systemImage: "archivebox")
                            }
                        }
                    }
                }

                Divider()
                    .overlay(Theme.border)
                    .padding(.leading, 46)

                Button {
                    addChildParent = item
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L10n.Settings.addSubcategory)
                            .font(AppFont.secondary)
                    }
                    .foregroundStyle(Theme.brand)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 42)
                    .padding(.leading, 46)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func moveTop(from source: IndexSet, to destination: Int) {
        var ordered = topLevel
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.order = index * 100
        }
        try? context.save()
    }

    private func restoreDefaults() {
        for entry in CategorySeed.entries {
            if let existing = categories.first(where: { $0.name == entry.name && $0.parentName == entry.parent }) {
                existing.isArchived = false
            } else {
                context.insert(CategoryItem(
                    name: entry.name,
                    icon: entry.icon,
                    colorHex: entry.colorHex,
                    order: entry.order,
                    parentName: entry.parent,
                    isSystem: true
                ))
            }
        }
        do {
            try context.save()
            toast.show(L10n.Toast.categoriesRestored)
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

private enum CategoryDeleteMode {
    case archive
    case merge
}

private struct DeleteCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]
    @Query private var records: [RecordItem]

    let item: CategoryItem
    @State private var mode: CategoryDeleteMode = .archive

    private var recordCount: Int {
        records.filter { $0.category == item.name || $0.subCategory == item.name }.count
    }

    private var categoryDescription: String {
        if let parent = item.parentName {
            return L10n.Settings.subcategoryOf(parent)
        }
        return L10n.Settings.topLevelCategory
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        CategoryBadge(icon: item.icon, colorHex: item.colorHex, size: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(AppFont.important)
                                .foregroundStyle(Theme.text)
                            Text("\(categoryDescription) · \(L10n.Settings.categoryRecordCount(recordCount))")
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

                    Text(L10n.Settings.historyQuestion)
                        .font(AppFont.smallMedium)
                        .foregroundStyle(Theme.text3)
                        .padding(.leading, 2)

                    VStack(spacing: 0) {
                        optionRow(
                            mode: .archive,
                            title: L10n.Settings.archiveOption,
                            description: L10n.Settings.archiveOptionDesc,
                            tag: L10n.Settings.recommended
                        )
                        Divider()
                            .overlay(Theme.border)
                            .padding(.leading, 14)
                        optionRow(
                            mode: .merge,
                            title: L10n.Settings.mergeOption,
                            description: L10n.Settings.mergeOptionDesc,
                            tag: nil
                        )
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }

                    Text(L10n.Settings.categoryDeleteNote)
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 2)

                    Button {
                        performDelete()
                    } label: {
                        Text(mode == .archive ? L10n.Settings.archiveAction : L10n.Settings.mergeAction)
                            .font(AppFont.important)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle(L10n.Settings.deleteCategory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.brand)
        .presentationDetents([.large])
    }

    private func optionRow(
        mode option: CategoryDeleteMode,
        title: String,
        description: String,
        tag: String?
    ) -> some View {
        Button {
            mode = option
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(AppFont.important)
                            .foregroundStyle(Theme.text)
                        if let tag {
                            Text(tag)
                                .font(AppFont.small)
                                .foregroundStyle(Theme.brand)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.brandSoft, in: Capsule())
                        }
                    }
                    Text(description)
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: mode == option ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(mode == option ? Theme.brand : Theme.chevron)
            }
            .padding(14)
            .background(mode == option ? Theme.brandSoft.opacity(0.55) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func performDelete() {
        if mode == .merge {
            for record in records where record.category == item.name || record.subCategory == item.name {
                record.category = L10n.Common.uncategorized
                record.subCategory = L10n.Common.uncategorized
            }
        }

        item.isArchived = true
        if item.parentName == nil {
            for child in categories where child.parentName == item.name {
                child.isArchived = true
            }
        }

        do {
            try context.save()
            toast.show(mode == .merge ? L10n.Toast.categoryMerged : L10n.Toast.categoryArchived)
            dismiss()
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

private struct SubCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]
    let parent: CategoryItem
    @State private var showAdd = false
    @State private var pendingOffsets: IndexSet?

    private var children: [CategoryItem] {
        categories.filter { $0.parentName == parent.name && !$0.isArchived }
    }

    var body: some View {
        List {
            ForEach(children) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    if item.isSystem {
                        Text(L10n.Common.system)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text3)
                    }
                }
            }
            .onDelete { offsets in
                pendingOffsets = offsets
            }
            .onMove { source, destination in
                var ordered = children
                ordered.move(fromOffsets: source, toOffset: destination)
                for (index, item) in ordered.enumerated() {
                    item.order = parent.order + index + 1
                }
                try? context.save()
            }
        }
        .pushedPageChrome(title: parent.name) {
            EditButton()
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .sheet(isPresented: $showAdd) {
            AddCategoryView(parent: parent)
        }
        .alert(
            L10n.Common.deleteConfirm,
            isPresented: Binding(
                get: { pendingOffsets != nil },
                set: { if !$0 { pendingOffsets = nil } }
            )
        ) {
            Button(L10n.Common.cancel, role: .cancel) { pendingOffsets = nil }
            Button(L10n.Common.delete, role: .destructive) { archivePendingChildren() }
        } message: {
            Text(L10n.Common.deleteMessage)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tint(Theme.brand)
    }

    private func archivePendingChildren() {
        guard let offsets = pendingOffsets else { return }
        for index in offsets {
            children[index].isArchived = true
        }
        pendingOffsets = nil
        do {
            try context.save()
            toast.show(L10n.Toast.categoryArchived)
        } catch {
            toast.show(L10n.Toast.saveFailed, style: .error)
        }
    }
}

private struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]

    var parent: CategoryItem? = nil
    @State private var name = ""

    private var topLevel: [CategoryItem] {
        categories.filter { $0.parentName == nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.Settings.categoryName, text: $name)
                    .font(AppFont.important)
                if parent == nil {
                    Text(L10n.Settings.newTopLevel)
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                } else {
                    Text(L10n.Settings.newUnder(parent?.name ?? ""))
                        .font(AppFont.small)
                        .foregroundStyle(Theme.text3)
                }
            }
            .font(AppFont.important)
            .navigationTitle(L10n.Settings.addCategory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
                        let order = (categories.map(\.order).max() ?? 0) + 1
                        let icon = parent?.icon ?? "其"
                        let color = parent?.colorHex ?? "94A3B8"
                        context.insert(CategoryItem(
                            name: name.trimmingCharacters(in: .whitespaces),
                            icon: icon,
                            colorHex: color,
                            order: order,
                            parentName: parent?.name
                        ))
                        do {
                            try context.save()
                            toast.show(L10n.Toast.categoryAdded)
                            dismiss()
                        } catch {
                            toast.show(L10n.Toast.saveFailed, style: .error)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .tint(Theme.brand)
    }
}

private struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.brandGradient)
                        .frame(width: 68, height: 68)
                        .overlay {
                            Text("记")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    Text(L10n.About.appName)
                        .font(.system(size: 16, weight: .semibold))
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.clear)
            }

            Section {
                Text(L10n.About.desc)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text2)
            }
        }
        .pushedPageChrome(title: L10n.About.title)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [RecordItem.self, CategoryItem.self], inMemory: true)
}
