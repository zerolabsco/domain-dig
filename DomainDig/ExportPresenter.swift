import SwiftUI
import UIKit

enum ExportPresenter {
    static func share(filename: String, contents: String) {
        share(filename: filename, data: Data(contents.utf8))
    }

    static func share(filename: String, data: Data) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }

        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.keyWindow?.rootViewController else {
            return
        }

        var presenter = rootViewController
        while let presentedViewController = presenter.presentedViewController {
            presenter = presentedViewController
        }

        activityController.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityController, animated: true)
    }
}
