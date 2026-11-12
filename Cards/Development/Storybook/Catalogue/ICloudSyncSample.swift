import Foundation

/// Each iCloud Sync status, for the settings story's iCloud status knob (DATA-10).
enum ICloudSyncSample: String, CaseIterable {
    case checking = "Checking"
    case syncing = "Syncing"
    case upToDate = "Up to date"
    case noAccount = "Not signed in"
    case unavailable = "Unavailable"
    case offline = "Offline"
    case offlineNeverSynced = "Offline, never synced"
    case storageFull = "Storage full"
    case failed = "Failed"

    var status: ICloudSyncStatus {
        let lastSynced = Date.now.addingTimeInterval(-3 * 60 * 60)
        return switch self {
        case .checking:
            .checking
        case .syncing:
            .syncing
        case .upToDate:
            .upToDate(lastSynced: .now.addingTimeInterval(-3 * 60))
        case .noAccount:
            .noAccount
        case .unavailable:
            .unavailable
        case .offline:
            .offline(lastSynced: lastSynced)
        case .offlineNeverSynced:
            .offline(lastSynced: nil)
        case .storageFull:
            .storageFull
        case .failed:
            .failed(lastSynced: lastSynced)
        }
    }
}
