import Foundation

// MARK: - DNS Models

enum DNSRecordType: String, CaseIterable {
    case A
    case AAAA
    case MX
    case NS
    case TXT
    case CNAME

    var queryType: Int {
        switch self {
        case .A: return 1
        case .AAAA: return 28
        case .MX: return 15
        case .NS: return 2
        case .TXT: return 16
        case .CNAME: return 5
        }
    }
}

struct DNSRecord: Identifiable {
    let id = UUID()
    let value: String
    let ttl: Int
}

struct DNSSection: Identifiable {
    let id = UUID()
    let recordType: DNSRecordType
    var records: [DNSRecord]
    var wildcardRecords: [DNSRecord] = []
    var error: String?
}

// MARK: - SSL Models

struct SSLCertificateInfo {
    let commonName: String
    let subjectAltNames: [String]
    let issuer: String
    let validFrom: Date
    let validUntil: Date
    let daysUntilExpiry: Int
    let chainDepth: Int
}

// MARK: - Cloudflare DNS-over-HTTPS Response

struct CloudflareDNSResponse: Decodable {
    let Status: Int
    let Answer: [CloudflareDNSAnswer]?

    struct CloudflareDNSAnswer: Decodable {
        let name: String
        let type: Int
        let TTL: Int
        let data: String
    }
}
