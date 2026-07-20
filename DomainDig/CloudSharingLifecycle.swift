import CloudKit
import UIKit

final class DomainDigAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = DomainDigSceneDelegate.self
        return configuration
    }
}

final class DomainDigSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        accept(metadata: metadata)
    }

    func windowScene(_: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        accept(metadata: cloudKitShareMetadata)
    }

    private func accept(metadata: CKShare.Metadata) {
        Task {
            try? await CloudSyncService.shared.acceptShare(metadata: metadata)
        }
    }
}
