import Foundation

extension Notification.Name {
    static let payrollPreferencesDidChange = Notification.Name("record.payroll.preferences.didChange")
}

struct PayrollPreferences: Codable, Equatable {
    var salaryTaxMonthMode: SalaryTaxMonthMode = .current

    static let storageKey = "record.payroll.preferences.v1"

    static func load() -> PayrollPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(PayrollPreferences.self, from: data) else {
            return PayrollPreferences()
        }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        NotificationCenter.default.post(name: .payrollPreferencesDidChange, object: nil)
    }
}
