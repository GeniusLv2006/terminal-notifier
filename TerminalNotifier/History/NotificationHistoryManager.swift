import Foundation

struct NotificationRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let badgeLabel: String
    let message: String
    let category: String
}

class NotificationHistoryManager {
    private let maxRecords = 100
    private let storageKey: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(storageKey: String = "notificationHistory") {
        self.storageKey = storageKey
    }

    func addRecord(_ record: NotificationRecord) {
        var records = getRecords()
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        saveRecords(records)
    }

    func getRecords() -> [NotificationRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? decoder.decode([NotificationRecord].self, from: data)) ?? []
    }

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func saveRecords(_ records: [NotificationRecord]) {
        guard let data = try? encoder.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
