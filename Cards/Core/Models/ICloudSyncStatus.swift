import Foundation

/// The iCloud account the cards sync through, as CloudKit reports it.
public enum ICloudAccount: Hashable, Sendable {
    case available
    /// No one is signed in to iCloud on the device.
    case noAccount
    /// Restricted by Screen Time or a profile, or not available for now.
    case unavailable
    /// Not known yet, or CloudKit could not say.
    case unknown
}

/// One piece of the syncing SwiftData does through CloudKit: setting up,
/// fetching the changes in iCloud or sending this device's, from its start
/// to its end.
public struct ICloudSyncEvent: Hashable, Sendable {
    /// What the piece of syncing does.
    public enum Kind: Hashable, Sendable {
        case setup
        /// Fetching the changes in iCloud.
        case `import`
        /// Sending this device's changes to iCloud.
        case export
    }

    /// Why a piece of syncing failed, as far as Settings tells them apart.
    public enum Failure: Hashable, Sendable, Comparable {
        /// Something else went wrong.
        case other
        /// The device is offline, or iCloud could not be reached.
        case offline
        /// No one is signed in to iCloud.
        case signedOut
        /// The iCloud account has no room left.
        case storageFull
    }

    public var id: UUID
    public var kind: Kind
    /// When it ended, or nil while it runs.
    public var ended: Date?
    /// Why it failed, or nil when it worked or is still running.
    public var failure: Failure?

    public init(id: UUID, kind: Kind, ended: Date? = nil, failure: Failure? = nil) {
        self.id = id
        self.kind = kind
        self.ended = ended
        self.failure = failure
    }
}

/// What Settings says about iCloud Sync while it is on (DATA-10).
public enum ICloudSyncStatus: Hashable, Sendable {
    /// Nothing is known yet: the store has only just opened.
    case checking
    case noAccount
    case unavailable
    case syncing
    /// Everything is in iCloud and here, as of `lastSynced`.
    case upToDate(lastSynced: Date)
    /// The last try could not reach iCloud; it synced last at `lastSynced`, if ever.
    case offline(lastSynced: Date?)
    case storageFull
    /// The last try failed for another reason.
    case failed(lastSynced: Date?)
}

/// Follows the account and the syncing of the store that is open, to say how
/// iCloud Sync is going.
public struct ICloudSyncTracker: Hashable, Sendable {
    public var account = ICloudAccount.unknown {
        didSet {
            // Signing in is what that failure was waiting for.
            if account == .available {
                failures = failures.filter { $0.value != .signedOut }
            }
        }
    }

    /// When syncing last ended well with this store, or on an earlier run.
    public private(set) var lastSynced: Date?
    /// Whether anything has ended well since the store opened.
    private var syncedSinceOpening = false
    private var running: Set<UUID> = []
    /// Why each kind of syncing failed the last time it ended, until it next
    /// works, so one kind working does not hide another failing.
    private var failures: [ICloudSyncEvent.Kind: ICloudSyncEvent.Failure] = [:]

    public init(lastSynced: Date? = nil) {
        self.lastSynced = lastSynced
    }

    /// Takes in a piece of syncing as it starts or ends.
    public mutating func record(_ event: ICloudSyncEvent) {
        guard let ended = event.ended else {
            running.insert(event.id)
            return
        }
        running.remove(event.id)
        failures[event.kind] = event.failure
        if event.failure == nil {
            syncedSinceOpening = true
            lastSynced = max(lastSynced ?? ended, ended)
        }
    }

    /// Starts again for a store opened afresh, as when iCloud Sync is turned
    /// off or on: nothing of the old store's is still running or failing.
    /// Turned off, the cards in iCloud may be deleted, so when they last
    /// synced no longer says anything about them.
    public mutating func storeOpened(syncsWithICloud: Bool) {
        running = []
        failures = [:]
        syncedSinceOpening = false
        if !syncsWithICloud {
            lastSynced = nil
        }
    }

    public var status: ICloudSyncStatus {
        switch account {
        case .noAccount:
            return .noAccount
        case .unavailable:
            return .unavailable
        case .available, .unknown:
            break
        }
        if !running.isEmpty {
            return .syncing
        }
        switch failures.values.max() {
        case .offline:
            return .offline(lastSynced: lastSynced)
        case .storageFull:
            return .storageFull
        case .signedOut:
            return .noAccount
        case .other:
            return .failed(lastSynced: lastSynced)
        case nil:
            break
        }
        // An earlier run's sync counts once the account is known to be there, or this store has synced.
        guard let lastSynced, syncedSinceOpening || account == .available else { return .checking }
        return .upToDate(lastSynced: lastSynced)
    }
}
