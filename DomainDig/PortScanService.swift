import Foundation
import Network

struct PortScanService {
    struct PortInfo: Sendable {
        let port: UInt16
        let service: String
    }

    static let ports: [PortInfo] = [
        PortInfo(port: 21, service: "FTP"),
        PortInfo(port: 22, service: "SSH"),
        PortInfo(port: 25, service: "SMTP"),
        PortInfo(port: 80, service: "HTTP"),
        PortInfo(port: 443, service: "HTTPS"),
        PortInfo(port: 587, service: "SMTP (TLS)"),
        PortInfo(port: 3306, service: "MySQL"),
        PortInfo(port: 5432, service: "PostgreSQL"),
        PortInfo(port: 8080, service: "HTTP Alt"),
        PortInfo(port: 8443, service: "HTTPS Alt"),
    ]

    static func scanAll(domain: String) async -> [PortScanResult] {
        await withTaskGroup(of: PortScanResult.self, returning: [PortScanResult].self) { group in
            for info in ports {
                group.addTask {
                    let open = await probe(domain: domain, port: info.port)
                    return PortScanResult(port: info.port, service: info.service, open: open)
                }
            }

            var results: [PortScanResult] = []
            for await result in group {
                results.append(result)
            }

            // Sort by port number
            return results.sorted { $0.port < $1.port }
        }
    }

    private static func probe(domain: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(domain)
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let connection = NWConnection(host: host, port: nwPort, using: .tcp)
            let context = ProbeContext(connection: connection, continuation: continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    context.finish(open: true)
                case .failed, .cancelled:
                    context.finish(open: false)
                default:
                    break
                }
            }

            let queue = DispatchQueue(label: "portscan.\(port)")
            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 3) {
                context.finish(open: false)
            }
        }
    }
}

private final class ProbeContext: @unchecked Sendable {
    private let connection: NWConnection
    private let continuation: CheckedContinuation<Bool, Never>
    private let lock = NSLock()
    private nonisolated(unsafe) var resumed = false

    init(connection: NWConnection, continuation: CheckedContinuation<Bool, Never>) {
        self.connection = connection
        self.continuation = continuation
    }

    nonisolated func finish(open: Bool) {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        lock.unlock()

        connection.cancel()
        continuation.resume(returning: open)
    }
}
