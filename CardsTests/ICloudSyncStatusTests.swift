@testable import Cards
import CloudKit
import Foundation
import Testing

/// What Settings says about iCloud Sync, from the account and the syncing
/// since the app opened (DATA-10).
struct ICloudSyncStatusTests {
    private let earlier = Date(timeIntervalSince1970: 1_790_000_000)
    private let later = Date(timeIntervalSince1970: 1_790_000_600)

    @Test func nothingKnownIsCheckingAndAnEarlierSyncIsUpToDateOnceTheAccountIsThere() {
        #expect(ICloudSyncTracker().status == .checking)
        var tracker = ICloudSyncTracker(lastSynced: earlier)
        #expect(tracker.status == .checking)
        tracker.account = .available
        #expect(tracker.status == .upToDate(lastSynced: earlier))
    }

    @Test func syncingLastsUntilEveryPieceHasEnded() {
        var tracker = ICloudSyncTracker()
        let setUp = UUID()
        let fetch = UUID()
        tracker.record(ICloudSyncEvent(id: setUp, kind: .setup))
        tracker.record(ICloudSyncEvent(id: fetch, kind: .import))
        #expect(tracker.status == .syncing)
        tracker.record(ICloudSyncEvent(id: setUp, kind: .setup, ended: earlier))
        #expect(tracker.status == .syncing)
        tracker.record(ICloudSyncEvent(id: fetch, kind: .import, ended: later))
        #expect(tracker.status == .upToDate(lastSynced: later))
    }

    @Test func aFailureSaysWhyAndKeepsWhenItLastSynced() {
        var tracker = ICloudSyncTracker(lastSynced: earlier)
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .export, ended: later, failure: .offline))
        #expect(tracker.status == .offline(lastSynced: earlier))
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .export, ended: later, failure: .other))
        #expect(tracker.status == .failed(lastSynced: earlier))
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .export, ended: later, failure: .storageFull))
        #expect(tracker.status == .storageFull)
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .export, ended: later))
        #expect(tracker.status == .upToDate(lastSynced: later))
    }

    /// Fetching working does not hide sending failing, whichever ends last.
    @Test func oneKindWorkingDoesNotHideAnotherFailing() {
        var tracker = ICloudSyncTracker()
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .export, ended: earlier, failure: .storageFull))
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .import, ended: later))
        #expect(tracker.status == .storageFull)
    }

    @Test func theAccountComesFirst() {
        var tracker = ICloudSyncTracker(lastSynced: earlier)
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .import))
        tracker.account = .noAccount
        #expect(tracker.status == .noAccount)
        tracker.account = .unavailable
        #expect(tracker.status == .unavailable)
        tracker.account = .available
        #expect(tracker.status == .syncing)
    }

    @Test func signingInClearsTheFailureThatWaitedForIt() {
        var tracker = ICloudSyncTracker(lastSynced: earlier)
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .setup, ended: later, failure: .signedOut))
        #expect(tracker.status == .noAccount)
        tracker.account = .available
        #expect(tracker.status == .upToDate(lastSynced: earlier))
    }

    /// Turning iCloud Sync off or on opens a new store: the old one's syncing is gone,
    /// and once it is off, when the cards last synced no longer counts.
    @Test func aNewStoreStartsAgain() {
        var tracker = ICloudSyncTracker(lastSynced: earlier)
        tracker.account = .available
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .export))
        tracker.storeOpened(syncsWithICloud: true)
        #expect(tracker.status == .upToDate(lastSynced: earlier))
        tracker.storeOpened(syncsWithICloud: false)
        #expect(tracker.lastSynced == nil)
        #expect(tracker.status == .checking)
    }

    @Test func anOlderSyncNeverMovesTheLastOneBack() {
        var tracker = ICloudSyncTracker(lastSynced: later)
        tracker.record(ICloudSyncEvent(id: UUID(), kind: .import, ended: earlier))
        #expect(tracker.lastSynced == later)
    }

    @Test(arguments: [
        (CKError.errorDomain, CKError.networkUnavailable.rawValue, ICloudSyncEvent.Failure.offline),
        (CKError.errorDomain, CKError.networkFailure.rawValue, .offline),
        (CKError.errorDomain, CKError.requestRateLimited.rawValue, .offline),
        (NSURLErrorDomain, NSURLErrorNotConnectedToInternet, .offline),
        (CKError.errorDomain, CKError.quotaExceeded.rawValue, .storageFull),
        (CKError.errorDomain, CKError.notAuthenticated.rawValue, .signedOut),
        (NSCocoaErrorDomain, 134_400, .signedOut),
        (CKError.errorDomain, CKError.internalError.rawValue, .other)
    ])
    func errorsComeDownToAReason(domain: String, code: Int, failure: ICloudSyncEvent.Failure) {
        #expect(ICloudSyncEvent.Failure(NSError(domain: domain, code: code)) == failure)
    }

    /// CloudKit wraps each record's error in a partial failure, and Core Data wraps CloudKit's.
    @Test func theReasonIsFoundInTheErrorsAFailureWraps() {
        let full = NSError(domain: CKError.errorDomain, code: CKError.quotaExceeded.rawValue)
        let offline = NSError(domain: CKError.errorDomain, code: CKError.networkFailure.rawValue)
        let partial = NSError(
            domain: CKError.errorDomain,
            code: CKError.partialFailure.rawValue,
            userInfo: [CKPartialErrorsByItemIDKey: ["a": offline, "b": full] as [AnyHashable: NSError]]
        )
        let coreData = NSError(domain: NSCocoaErrorDomain, code: 134_404, userInfo: [NSUnderlyingErrorKey: partial])
        #expect(ICloudSyncEvent.Failure(coreData) == .storageFull)
    }

    @MainActor @Test func theMonitorKeepsWhenItLastSyncedUntilSyncIsTurnedOff() async throws {
        let defaults = try #require(UserDefaults(suiteName: "ICloudSyncStatusTests"))
        defaults.removePersistentDomain(forName: "ICloudSyncStatusTests")
        let ended = earlier
        let sync = ICloudSync(
            account: { .available },
            changes: {
                AsyncStream { continuation in
                    continuation.yield(.event(ICloudSyncEvent(id: UUID(), kind: .import, ended: ended)))
                    continuation.finish()
                }
            }
        )
        await ICloudSyncMonitor(sync: sync, defaults: defaults).run()
        #expect(defaults.object(forKey: DeviceSettings.iCloudLastSyncedKey) as? Date == earlier)
        let relaunched = ICloudSyncMonitor(sync: sync, defaults: defaults)
        #expect(relaunched.tracker.lastSynced == earlier)
        relaunched.storeOpened(syncsWithICloud: false)
        #expect(defaults.object(forKey: DeviceSettings.iCloudLastSyncedKey) == nil)
    }

    /// An account that never answers, as on a simulator signed out of iCloud,
    /// holds up neither the syncing nor the end of the run.
    @MainActor @Test func aSlowAccountHoldsUpNothing() async {
        let ended = later
        let sync = ICloudSync(
            account: {
                try? await Task.sleep(for: .seconds(3_600))
                return .available
            },
            changes: {
                AsyncStream { continuation in
                    continuation.yield(.event(ICloudSyncEvent(id: UUID(), kind: .import, ended: ended)))
                    continuation.finish()
                }
            }
        )
        let monitor = ICloudSyncMonitor(sync: sync, defaults: UserDefaults(suiteName: "ICloudSyncStatusTestsSlow") ?? .standard)
        await monitor.run()
        #expect(monitor.tracker.lastSynced == later)
    }
}
