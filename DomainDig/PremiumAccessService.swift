import Foundation

enum PremiumAccessService {
    static func hasAccess(to capability: PremiumCapability) -> Bool {
        switch capability {
        case .advancedExports:
            return FeatureAccessService.hasAccess(to: .advancedExports)
        case .batchTracking:
            return FeatureAccessService.hasAccess(to: .batchOperations)
        case .unlimitedTrackedDomains:
            return FeatureAccessService.currentTier != .free
        case .automatedMonitoring:
            return FeatureAccessService.hasAccess(to: .automatedMonitoring)
        case .pushAlerts:
            return FeatureAccessService.hasAccess(to: .localAlerts)
        }
    }

    static func trackedDomainLimitMessage(currentCount: Int) -> String? {
        FeatureAccessService.trackedDomainLimitMessage(currentCount: currentCount)
    }

    static func canAddTrackedDomain(currentCount: Int) -> Bool {
        FeatureAccessService.canAddTrackedDomain(currentCount: currentCount)
    }
}
