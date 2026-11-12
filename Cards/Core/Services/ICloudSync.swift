import CloudKit
import CoreData
import OSLog

/// What iCloud Sync is doing, for Settings to show (DATA-10): the account it
/// syncs through, and each piece of syncing SwiftData does as it starts and
/// ends. Injected, so only the live value reaches CloudKit.
public struct ICloudSync: Sendable {
    /// A change worth looking at the status again for.
    public enum Change: Hashable, Sendable {
        case event(ICloudSyncEvent)
        /// Someone signed in or out of iCloud, or the account changed.
        case accountChanged
    }

    /// The iCloud account's status now.
    public var account: @Sendable () async -> ICloudAccount
    /// Every change from now on. It is listening by the time it returns, so a
    /// store opened after it misses none of its syncing.
    public var changes: @Sendable () -> AsyncStream<Change>

    public init(account: @escaping @Sendable () async -> ICloudAccount, changes: @escaping @Sendable () -> AsyncStream<Change>) {
        self.account = account
        self.changes = changes
    }
}

public extension ICloudSync {
    /// The app's iCloud container, and the events SwiftData's CloudKit mirroring
    /// posts, which it posts as Core Data does underneath.
    static let live = Self(
        account: {
            do {
                let status = try await CKContainer(identifier: CardStore.iCloudContainer).accountStatus()
                logger.debug("iCloud account status: \(status.rawValue, privacy: .public)")
                return switch status {
                case .available:
                    .available
                case .noAccount:
                    .noAccount
                case .restricted, .temporarilyUnavailable:
                    .unavailable
                case .couldNotDetermine:
                    .unknown
                @unknown default:
                    .unknown
                }
            } catch {
                logger.error("Could not read the iCloud account status: \(error.localizedDescription, privacy: .public)")
                return .unknown
            }
        },
        changes: {
            // Observers, rather than NotificationCenter's async sequences, so it is
            // listening before this returns.
            AsyncStream { continuation in
                let center = NotificationCenter.default
                let observers = Observers([
                    center.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil) { notification in
                        let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                        guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return }
                        logger.debug(
                            "iCloud sync event \(event.type.rawValue, privacy: .public): ended \(event.endDate != nil), succeeded \(event.succeeded)"
                        )
                        continuation.yield(.event(ICloudSyncEvent(event)))
                    },
                    center.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { _ in
                        continuation.yield(.accountChanged)
                    }
                ])
                continuation.onTermination = { _ in observers.remove() }
            }
        }
    )

    private static let logger = Logger(subsystem: "net.serby.Cards", category: "ICloudSync")
}

/// NotificationCenter's observer tokens, removed together once the stream ends.
private final class Observers: @unchecked Sendable {
    // Only read again by `remove()`, once, when the stream ends.
    private let tokens: [any NSObjectProtocol]

    init(_ tokens: [any NSObjectProtocol]) {
        self.tokens = tokens
    }

    func remove() {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}

extension ICloudSyncEvent {
    init(_ event: NSPersistentCloudKitContainer.Event) {
        self.init(
            id: event.identifier,
            kind: Kind(event.type),
            ended: event.endDate,
            failure: event.endDate == nil || event.succeeded ? nil : Failure(event.error)
        )
    }
}

extension ICloudSyncEvent.Kind {
    init(_ type: NSPersistentCloudKitContainer.EventType) {
        switch type {
        case .setup:
            self = .setup
        case .import:
            self = .import
        case .export:
            self = .export
        @unknown default:
            self = .export
        }
    }
}

extension ICloudSyncEvent.Failure {
    /// What `error`, from a piece of syncing that failed, comes down to: the
    /// most serious reason in it, or in the errors it wraps, as CloudKit wraps
    /// each record's error in a partial failure and Core Data wraps CloudKit's.
    init(_ error: (any Error)?) {
        self = Self.reasons(in: error as NSError?).max() ?? .other
    }

    /// Core Data's "Unable to initialize without an iCloud account".
    static let noAccountCode = 134_400

    private static func reasons(in error: NSError?, depth: Int = 0) -> [Self] {
        guard let error, depth < 4 else { return [] }
        let wrapped = [error.userInfo[NSUnderlyingErrorKey] as? NSError]
            + ((error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError]).map { Array($0.values) } ?? [])
        let inner = wrapped.flatMap { reasons(in: $0, depth: depth + 1) }
        return inner.isEmpty ? [reason(of: error)] : inner + [reason(of: error)].filter { $0 != .other }
    }

    private static func reason(of error: NSError) -> Self {
        switch (error.domain, error.code) {
        case (CKError.errorDomain, CKError.networkUnavailable.rawValue), (CKError.errorDomain, CKError.networkFailure.rawValue),
             (CKError.errorDomain, CKError.serviceUnavailable.rawValue), (CKError.errorDomain, CKError.requestRateLimited.rawValue),
             (CKError.errorDomain, CKError.zoneBusy.rawValue), (NSURLErrorDomain, _):
            .offline
        case (CKError.errorDomain, CKError.quotaExceeded.rawValue):
            .storageFull
        case (CKError.errorDomain, CKError.notAuthenticated.rawValue), (NSCocoaErrorDomain, noAccountCode):
            .signedOut
        default:
            .other
        }
    }
}
