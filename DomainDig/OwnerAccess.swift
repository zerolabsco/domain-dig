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
