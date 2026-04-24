import CloudKit
import Foundation
import SwiftUI
import UIKit

struct CloudSharingSheet: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let entity: ShareableEntity
    let title: String

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, title: title)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.presentIfNeeded(from: uiViewController, entity: entity)
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        private let dismissAction: DismissAction
        private let title: String
        private let observer = CKSystemSharingUIObserver(container: .default())
        private var hasPresented = false

        init(dismiss: DismissAction, title: String) {
            self.dismissAction = dismiss
            self.title = title
            super.init()

            observer.systemSharingUIDidSaveShareBlock = { _, _ in
                Task { @MainActor in
                    await CloudSyncService.shared.syncNow(trigger: .manual)
                }
            }

            observer.systemSharingUIDidStopSharingBlock = { _, _ in
                Task { @MainActor in
                    await CloudSyncService.shared.syncNow(trigger: .manual)
                }
            }
        }

        func presentIfNeeded(from presenter: UIViewController, entity: ShareableEntity) {
            guard !hasPresented else { return }
            hasPresented = true

            let itemProvider = NSItemProvider()
            let container = CKContainer.default()

            Task { @MainActor in
                do {
                    if let existingShare = try await CloudSyncService.shared.existingShare(for: entity) {
                        itemProvider.registerCKShare(existingShare, container: container)
                    } else {
                        itemProvider.registerCKShare(container: container) {
                            try await CloudSyncService.shared.createShare(for: entity)
                        }
                    }
                } catch {
                    dismissAction()
                    return
                }

                let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
                let activityController = UIActivityViewController(activityItemsConfiguration: configuration)
                activityController.completionWithItemsHandler = { [dismissAction] _, _, _, _ in
                    dismissAction()
                }
                activityController.popoverPresentationController?.sourceView = presenter.view
                activityController.presentationController?.delegate = self
                presenter.present(activityController, animated: true)
            }
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            dismissAction()
        }
    }
}
