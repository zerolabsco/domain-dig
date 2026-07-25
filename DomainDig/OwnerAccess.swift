import CloudKit

/// Owner-only entitlement support. The app owner is identified by their CloudKit
/// user-record ID — a stable, opaque per-Apple-ID value for this app's container
/// that other users cannot guess or spoof — so a release build can grant the
/// owner Pro+ without a purchase.
///
/// `ownerUserRecordID` is empty until configured; an empty value never matches,
/// so the allowlist is inert until the owner's real record ID is filled in. Read
/// your own value from the DEBUG "Developer" row in Settings → App Info.
enum OwnerAccess {
    /// The owner's CloudKit user-record name. Empty = unconfigured (inert).
    static let ownerUserRecordID = ""

    static var isConfigured: Bool { !ownerUserRecordID.isEmpty }

    /// The current iCloud user's record name for this app's container, or nil if
    /// it is unavailable (not signed into iCloud, restricted, or offline before
    /// the first fetch).
    static func currentUserRecordName() async -> String? {
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
