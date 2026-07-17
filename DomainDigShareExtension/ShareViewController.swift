import UIKit
import UniformTypeIdentifiers

/// Receives a web URL from the share sheet, extracts its host, and hands it to
/// the app through the App Group inbox. Shows a brief confirmation and closes;
/// the app picks up the domain the next time it becomes active.
final class ShareViewController: UIViewController {
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        label.text = "Saving…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        extractSharedDomain { [weak self] domain in
            DispatchQueue.main.async {
                self?.finish(domain: domain)
            }
        }
    }

    private func extractSharedDomain(completion: @escaping (String?) -> Void) {
        let providers = (extensionContext?.inputItems ?? [])
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }

        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) else {
            completion(nil)
            return
        }

        provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
            let url = item as? URL ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
            let host = url?.host?.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(host?.isEmpty == false ? host : nil)
        }
    }

    private func finish(domain: String?) {
        if let domain {
            DomainDigShareInbox.write(domain: domain)
            label.text = "Saved \(domain) — open DomainDig to inspect it."
        } else {
            label.text = "No web address found."
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
