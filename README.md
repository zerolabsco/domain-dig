# DomainDig

[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=zerolabsco_domain-dig&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=zerolabsco_domain-dig)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=zerolabsco_domain-dig&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=zerolabsco_domain-dig)

DomainDig is a local-first iOS domain inspection toolkit for DNS, web, ownership, monitoring, reporting, and audit workflows. The app gathers a point-in-time domain snapshot, normalizes it into a canonical `DomainReport`, and keeps user data on device unless the user exports, shares, or syncs it.

## Current Release Target

Immediate release target: `v4.4.1`.

This patch release focuses on release readiness: resolving duplicate Audit Mode implementations, aligning app/project version metadata, preserving audit persistence and backup/restore coverage, and refreshing docs for the current app surface.

## Features

- Domain inspection for DNS records, email security, TLS certificates, HTTP headers, redirects, IP geolocation, reachability, open ports, RDAP, ownership, subdomain discovery, and availability.
- Canonical `DomainReport` output used by the app UI and exports.
- History snapshots with change summaries, risk scoring, notes, and saved domain context.
- Dashboard, watchlist, monitoring, workflows, batch results, integrations, and data portability screens.
- Audit Mode with sessions, checklist progress, reviewer notes, findings, evidence snapshots, audit timelines, and markdown/json/pdf export.
- Backup and restore for tracked domains, history, audit sessions, workflows, monitoring settings/logs, app settings, and local feature metadata.
- Local-first operation with no required backend.
- Optional local API surface for automation-compatible report output.

## Data And Privacy

DomainDig stores local app data in on-device persistence. Backup exports can include tracked domains, lookup history, audit sessions, workflow definitions, monitoring configuration, monitoring logs, app settings, and cached feature metadata. Imports are processed on device.

Network inspection requests are made only to perform the requested domain checks or configured resolver lookups. The app does not require a hosted DomainDig backend.

## Development

### Requirements

- Xcode with current iOS SDK support
- iOS Simulator or physical iOS device
- Swift/Xcode support for filesystem-synchronized groups used by the project

### Getting Started

1. Clone the repository.
   ```sh
   git clone https://github.com/zerolabsco/domain-dig.git
   ```
2. Open `DomainDig.xcodeproj` in Xcode.
3. Select the `DomainDig` scheme.
4. Build and run on a simulator or device.

### Useful Checks

```sh
xcodebuild -project DomainDig.xcodeproj -scheme DomainDig -destination 'platform=iOS Simulator,name=iPhone 16' build
```

The app and local API share the canonical report pipeline through `DomainInspectionService`, `DomainReportBuilder`, and `DomainReportExporter`.

## Release Planning

See `RELEASE_ROADMAP.md` for the semver release plan from `v4.4.1` through the planned `v5.0.0` stabilization milestone.

## Contributing

Contributions are welcome. Keep changes scoped, include tests or build verification when behavior changes, and open a pull request with a clear summary of user-facing impact.

## Security

If you discover a security issue, see `SECURITY.md`.

## License

This project is licensed under GPL 3.0 or later. See `LICENSE`.

## Contact

Questions or feedback: hello@cleberg.net
