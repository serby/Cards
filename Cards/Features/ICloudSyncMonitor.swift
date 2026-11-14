import Foundation
import Observation

/// Follows iCloud Sync from the moment the app opens, so Settings can say how
/// it is going as soon as it is shown (DATA-10). When syncing last ended well
/// is kept on the device, so the status still says it after a relaunch.
@MainActor
@Observable
public final class ICloudSyncMonitor {
    public private(set) var tracker: ICloudSyncTracker
    @ObservationIgnored private let sync: ICloudSync
    @ObservationIgnored private let defaults: UserDefaults
    /// Listening from the moment the monitor is made, which CardsApp does
    /// before it opens the store, so the store's first syncing is not missed.
    @ObservationIgnored private let changes: AsyncStream<ICloudSync.Change>
    /// Where a piece of syncing that failed is logged, with Share Diagnostics on (PLAT-14).
    @ObservationIgnored private let telemetry: Telemetry
    /// How many times the account has been asked for.
    @ObservationIgnored private var accountReads = 0

    public init(sync: ICloudSync, defaults: UserDefaults = .standard, telemetry: Telemetry = .silent) {
        self.sync = sync
        self.telemetry = telemetry
        self.defaults = defaults
        changes = sync.changes()
        tracker = ICloudSyncTracker(lastSynced: defaults.object(forKey: DeviceSettings.iCloudLastSyncedKey) as? Date)
    }

    public var status: ICloudSyncStatus {
        tracker.status
    }

    /// Follows the changes for as long as the task it runs in. Run it once, as
    /// CardsApp does for the life of the app: the changes have one reader. The
    /// account is asked for beside them, as CloudKit can take a long time to
    /// say, and the syncing is followed while it does.
    public func run() async {
        await withDiscardingTaskGroup { group in
            group.addTask { await self.readAccount() }
            for await change in changes {
                switch change {
                case let .event(event):
                    let before = tracker.lastSynced
                    tracker.record(event)
                    if let failure = event.failure {
                        telemetry.log("iCloud sync failed", ["kind": "\(event.kind)", "reason": "\(failure)"])
                    }
                    if let lastSynced = tracker.lastSynced, lastSynced != before {
                        defaults.set(lastSynced, forKey: DeviceSettings.iCloudLastSyncedKey)
                    }
                case .accountChanged:
                    group.addTask { await self.readAccount() }
                }
            }
            group.cancelAll()
        }
    }

    /// For a store opened afresh with iCloud Sync on or off (DATA-8), so
    /// nothing of the old store's is still running or failing.
    public func storeOpened(syncsWithICloud: Bool) {
        tracker.storeOpened(syncsWithICloud: syncsWithICloud)
        if !syncsWithICloud {
            defaults.removeObject(forKey: DeviceSettings.iCloudLastSyncedKey)
        }
    }

    /// Reads the account, keeping the answer only if no later read began
    /// meanwhile, so a slow answer never overwrites a newer one.
    private func readAccount() async {
        accountReads += 1
        let read = accountReads
        let account = await sync.account()
        if read == accountReads {
            tracker.account = account
        }
    }
}
