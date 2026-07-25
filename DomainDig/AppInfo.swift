import Foundation
import UIKit

/// Runtime app metadata read from the bundle, plus the locally-assembled
/// diagnostics used to prefill an issue report. Nothing here touches the network
/// or collects any identifier beyond the app version, iOS version, and hardware
/// model string.
enum AppInfo {
    /// CFBundleShortVersionString (marketing version), falling back to the
    /// compiled-in `AppVersion.current` if the Info.plist key is missing.
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppVersion.current
    }

    /// CFBundleVersion (build number).
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    /// "5.0.0 (build 45)" — version alongside build, as the App Info row shows it.
    static var versionDisplay: String {
        "\(marketingVersion) (build \(buildNumber))"
    }

    static let minimumOS = "17.6"

    static var systemVersion: String {
        UIDevice.current.systemVersion
    }

    /// Hardware model identifier (e.g. "iPhone15,2") — a model string, not a
    /// per-device identifier.
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }

    /// Diagnostics prefilled into an issue report. Shown to the user before any
    /// send — never collected silently.
    static var diagnosticsReport: String {
        """
        DomainDig \(versionDisplay)
        iOS \(systemVersion)
        Device \(deviceModel)
        """
    }
}
