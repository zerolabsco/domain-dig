import Foundation

enum PremiumAccessService {
    static func hasAccess(to capability: PremiumCapability) -> Bool {
        true
    }

    static func trackedDomainLimitMessage(currentCount: Int) -> String? {
        nil
    }

    static func canAddTrackedDomain(currentCount: Int) -> Bool {
        true
    }
}
