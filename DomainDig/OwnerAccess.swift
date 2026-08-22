import CloudKit

/// Owner-only entitlement support. The app owner is identified by their CloudKit
/// user-record ID — a stable, opaque per-Apple-ID value for this app's container.
/// `PurchaseService` grants the owner Pro+ when the signed-in iCloud user matches,
/// so the owner does not need a purchase.
///
/// Publishing the record ID here is safe: it is not an Apple ID or any personal
/// identifier, it is scoped to the `iCloud.net.cleberg.DomainDig` container, and
/// CloudKit identity is verified server-side — another user cannot present it as
/// their own. An empty value makes the allowlist inert.
enum OwnerAccess {
    static let ownerUserRecordID = "_1c35d6a25540b3ef00023cc0425ec373"

    static var isConfigured: Bool { !ownerUserRecordID.isEmpty }

    /// Whether this build actually carries its entitlements.
    ///
    /// Touching CloudKit without the iCloud container entitlement does not
    /// return an error — it raises an Objective-C exception from inside a
    /// `dispatch_once`, which Swift cannot catch, so the process aborts before
    /// the first screen draws. That is what any unsigned build does, including
    /// CI: `xcodebuild ... CODE_SIGNING_ALLOWED=NO` embeds no entitlements.
    ///
    /// The App Group is declared in the same entitlements file and is stripped
    /// by the same mechanism, but asking for its container returns nil rather
    /// than raising. So it answers the question CloudKit will not: does this
    /// process have its entitlements at all?
    private static var hasEntitlements: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DomainDigWidgetStore.appGroupID
        ) != nil
    }

    /// The current iCloud user's record name for this app's container, or nil if
    /// it is unavailable (not signed into iCloud, restricted, offline before the
    /// first fetch, or running from a build without entitlements).
    static func currentUserRecordName() async -> String? {
        guard hasEntitlements else { return nil }
        do {
            return try await CKContainer.default().userRecordID().recordName
        } catch {
            return nil
        }
    }

    /// True only when the allowlist is configured and the current iCloud user is
    /// the owner.
    static func isOwner() async -> Bool {
        guard isConfigured else { return false }
        return await currentUserRecordName() == ownerUserRecordID
    }
}
