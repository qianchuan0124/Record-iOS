import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable, Identifiable {
    case ledger
    case analysis
    case assets
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ledger: L10n.Tab.ledger
        case .analysis: L10n.Tab.analysis
        case .assets: L10n.Tab.assets
        case .settings: L10n.Tab.settings
        }
    }

    var icon: String {
        switch self {
        case .ledger: "list.bullet.rectangle"
        case .analysis: "chart.pie"
        case .assets: "building.columns"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var categories: [CategoryItem]
    @Query private var banks: [Bank]
    @State private var tab: AppTab = .ledger
    @State private var showEditor = false
    @AppStorage("record.appearance") private var appearance = "system"

    var body: some View {
        ZStack {
            Group {
                switch tab {
                case .ledger: LedgerView()
                case .analysis: AnalysisView()
                case .assets: AssetsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $tab) {
                showEditor = true
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay { ToastHost() }
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .preferredColorScheme(preferredScheme)
        .sheet(isPresented: $showEditor) {
            RecordEditorView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SyncFolderService.autoBackupIfNeeded(context: context)
            }
        }
        .task {
            CategorySeed.seedIfNeeded(context, existing: categories)
            BankSeed.seedIfNeeded(context, existing: banks)
            var currentBanks = (try? context.fetch(FetchDescriptor<Bank>())) ?? banks
            BankSeed.repairDefaultBanksIfNeeded(context, existing: currentBanks)
            currentBanks = (try? context.fetch(FetchDescriptor<Bank>())) ?? currentBanks
            BankSeed.seedFullCatalogIfNeeded(context, existing: currentBanks)
            #if DEBUG
            if CommandLine.arguments.contains("-seedDemo") {
                DemoSeed.seedIfNeeded(context)
            }
            if CommandLine.arguments.contains("-openEditor") {
                showEditor = true
            }
            if CommandLine.arguments.contains("-dark") {
                appearance = "dark"
            }
            if CommandLine.arguments.contains("-light") {
                appearance = "light"
            }
            if let index = CommandLine.arguments.firstIndex(of: "-tab"),
               CommandLine.arguments.indices.contains(index + 1),
               let requested = AppTab(rawValue: CommandLine.arguments[index + 1]) {
                tab = requested
            }
            #endif
        }
    }

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selection: AppTab
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.ledger)
            tabButton(.analysis)
            addButton
            tabButton(.assets)
            tabButton(.settings)
        }
        .padding(.top, 9)
        .padding(.bottom, 5)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(_ item: AppTab) -> some View {
        Button {
            selection = item
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .regular))
                    .frame(height: 25)
                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selection == item ? Theme.brand : Theme.text3)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.brandGradient, in: Circle())
                .shadow(color: Theme.brand.opacity(0.32), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .offset(y: -17)
        .zIndex(1)
        .accessibilityLabel(L10n.Tab.addRecord)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordItem.self, CategoryItem.self, Bank.self, DepositRecord.self, SalaryRecord.self, AnnualBonus.self, BudgetItem.self], inMemory: true)
}
