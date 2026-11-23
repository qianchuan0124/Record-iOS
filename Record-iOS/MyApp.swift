import SwiftUI
import SwiftData

@main
struct RecordIOSApp: App {
    @State private var toast = ToastCenter()
    private let container: ModelContainer = {
        let schema = Schema([
            RecordItem.self,
            CategoryItem.self,
            Bank.self,
            DepositRecord.self,
            SalaryRecord.self,
            AnnualBonus.self,
            BudgetItem.self
        ])
        let containerID = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String
        let cloudKit: ModelConfiguration.CloudKitDatabase = (containerID?.isEmpty == false) ? .automatic : .none
        let configuration = ModelConfiguration("Record", schema: schema, cloudKitDatabase: cloudKit)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(toast)
        }
        .modelContainer(container)
    }
}
