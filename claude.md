# DomainDig – Project Context

## What this is
An iOS utility app for querying DNS records, inspecting SSL/TLS certificates,
checking HTTP headers, measuring TCP reachability, geolocating IP addresses,
analyzing email security records, tracing redirect chains, performing reverse
DNS lookups, and scanning common ports for any domain. Designed for developers,
sysadmins, and anyone who manages or troubleshoots domains and servers.

## Target user
Technically literate adults — developers, IT/sysadmin, homelab enthusiasts.
Comfortable with terms like A record, CNAME, MX, TTL, and TLS. The UI should be
clean and information-dense, not hand-holding.

## Design principles
- Minimal, utilitarian UI — this is a tool, not a consumer app
- Results should be readable at a glance — use clear labels, monospace where
  appropriate for IPs and raw values
- Dark mode preferred as the primary aesthetic
- No onboarding, no tutorials, no splash screens
- Fast — results should appear as soon as they're available, not after all
  lookups complete
- Each result section loads independently with its own ProgressView
- Errors shown inline per-section, never as global alerts

## Features

### DNS Lookup
Query the following record types for any domain via DNS-over-HTTPS (use
Cloudflare 1.1.1.1 — https://cloudflare-dns.com/dns-query):
- A
- AAAA
- MX
- NS
- TXT
- CNAME

Display each record type in its own section. Show TTL alongside each result.
If a record type returns no results, show "No records found" for that type
rather than hiding the section entirely.

After the apex query, also queries `*.{domain}` for A, AAAA, MX, and TXT.
Wildcard results are shown as a sub-section beneath each record type, labelled
with `*.{domain}`. Hidden if no wildcard records are returned.

### SSL/TLS Certificate Check
Connect to the domain on port 443 via URLSession and inspect the server's
certificate chain using URLSession delegate methods. Display:
- Common name (CN)
- Subject Alternative Names (SANs)
- Issuer
- Valid from / Valid until dates
- Days until expiry — highlight in red if under 30 days, yellow if under 60
- Certificate chain depth

### HTTP Headers Check
Fire a HEAD request to `https://{domain}` and display all response headers.
Header names in cyan, values in primary. Security-relevant headers highlighted
in yellow: `strict-transport-security`, `x-frame-options`,
`x-content-type-options`, `content-security-policy`, `referrer-policy`.
Service: `HTTPHeadersService.swift`.

### Reachability / TCP Latency
Use `NWConnection` (Network framework) to attempt TCP connections on ports 443
and 80. Measure time to `.ready` state. Display green/red dot, latency in ms,
and reachable/unreachable status. Timeout after 5 seconds.
Service: `ReachabilityService.swift`.

### IP Geolocation with Map
After DNS A record resolves, take the first IP and query
`https://ipapi.co/{ip}/json/` for country, region, city, org, lat/lon.
Display in an "IP Location" section with a SwiftUI `Map` (MapKit) centered on
the coordinates with a `Marker`. Map height 180pt, `.standard` style.
Service: `IPGeolocationService.swift`.

### Email Security Analysis
Parse SPF from existing TXT records (no extra query). Query `_dmarc.{domain}`
for DMARC and try common DKIM selectors (`default`, `google`, `mail`) via DoH.
Display green checkmark if found, red ✗ if not. Full record values truncated
to 80 chars with tap-to-expand. Triggered after DNS completes.
Service: `EmailSecurityService.swift`.

### Reverse DNS / PTR Lookup
After DNS A record resolves, construct reverse DNS name (reversed octets +
`.in-addr.arpa`) and query PTR record via Cloudflare DoH. Displayed inline
in the DNS Records section below the A record sub-section.
Service: `ReverseDNSService.swift`.

### Redirect Chain
Fire HTTP request to `http://{domain}` with redirects disabled. Follow up to
10 redirects manually, recording each hop's URL and status code. Display step
number, status code in cyan, URL, and "(final)" on the last hop. Shows
"No redirects — direct connection" if the first request returns 200.
Service: `RedirectChainService.swift`.

### Common Port Scanner
Probe 10 common ports (21/FTP, 22/SSH, 25/SMTP, 80/HTTP, 443/HTTPS,
587/SMTP-TLS, 3306/MySQL, 5432/PostgreSQL, 8080/HTTP-Alt, 8443/HTTPS-Alt)
using `NWConnection` with 3-second timeout. All probes run concurrently.
Green dot for open, grey dot for closed. Closed is expected — no error shown.
Service: `PortScanService.swift`.

### Results layout
- Domain input at the top — large text field, keyboard shows on launch
- Run button to trigger all lookups simultaneously
- Results displayed in clearly separated sections:
  Reachability → Redirect Chain → DNS Records (with PTR inline) →
  Email Security → SSL/TLS Certificate → HTTP Headers → IP Location →
  Open Ports
- Each section loads independently — don't block one section waiting for another
- Email security, PTR, and IP geolocation are chained after DNS; all others
  run in parallel

### Recent searches
Store the last 20 searched domains locally using UserDefaults. Display them as
a tappable list below the text field when no results are showing. Tapping a
recent domain populates the text field and runs the lookup immediately. Include
a "Clear" button to wipe history. Most recent at the top.

### Saved domains
Bookmark button (SF Symbol: `bookmark` / `bookmark.fill`) in the results
toolbar area, next to the share button. Tapping saves/unsaves the current
domain. Filled icon when saved. Saved domains viewable from a toolbar button
that pushes to `SavedDomainsView` — a list of saved domains, tappable to run
lookups, with swipe-to-delete and an Edit button for bulk deletion.
Persisted in UserDefaults under key `savedDomains`.

### Lookup history with cached results
After each successful lookup, a snapshot of all results (DNS, SSL, HTTP headers,
reachability, geolocation, email security, PTR, redirect chain, port scan) is
saved to history in UserDefaults as JSON. Capped at 50 entries. `HistoryView`
shows past lookups with domain and timestamp. Tapping shows full cached results
in `HistoryDetailView` using the same layout, labelled as cached with the
original timestamp. Model: `HistoryEntry` (Codable).

### Share / export
A share button (SF Symbol: `square.and.arrow.up`) in the top-right of the
results area. Formats the full results as plain text and presents the iOS share
sheet via UIActivityViewController. The export includes: domain, timestamp,
reachability, redirect chain, all DNS records with TTLs and PTR, email security
records, SSL cert fields, HTTP headers, IP geolocation data, and port scan
results.

## Technical constraints
- SwiftUI, iOS only
- Fully offline except for network requests (DNS-over-HTTPS, SSL, HTTP HEAD,
  TCP connections, geolocation API)
- No accounts, no analytics, no ads
- No third-party dependencies — URLSession, Network, MapKit only
- Targets latest iOS

## Architecture
- `Models.swift` — All data models (DNS, SSL, HTTP headers, reachability,
  geolocation, history entry), all Codable for persistence
- `DomainViewModel.swift` — `@Observable` view model orchestrating all lookups,
  managing state, history, saved domains, recent searches, and export
- `ContentView.swift` — Main screen with input, all result sections, toolbar
- `SavedDomainsView.swift` — Saved domains list with edit/delete
- `HistoryView.swift` — History list + `HistoryDetailView` for cached results
- Services: `DNSLookupService`, `SSLCheckService`, `HTTPHeadersService`,
  `ReachabilityService`, `IPGeolocationService`, `EmailSecurityService`,
  `ReverseDNSService`, `RedirectChainService`, `PortScanService`

## What good looks like
A developer pastes a domain, taps run, and within a couple of seconds sees a
clean breakdown of TCP reachability, redirect chain, every DNS record type with
reverse DNS, email security posture, the full SSL cert status, HTTP response
headers with security headers highlighted, IP geolocation with a map, and a
port scan of common services. It should feel like a native, polished version of
running `dig`, `openssl s_client`, `curl -I`, `nmap`, and `whois` from the
terminal.
