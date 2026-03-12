# DomainDig – Project Context

## What this is
An iOS utility app for querying DNS records and inspecting SSL/TLS certificates
for any domain. Designed for developers, sysadmins, and anyone who manages or
troubleshoots domains and servers.

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

### SSL/TLS Certificate Check
Connect to the domain on port 443 via URLSession and inspect the server's
certificate chain using URLSession delegate methods. Display:
- Common name (CN)
- Subject Alternative Names (SANs)
- Issuer
- Valid from / Valid until dates
- Days until expiry — highlight in red if under 30 days, yellow if under 60
- Certificate chain depth

### Results layout
- Domain input at the top — large text field, keyboard shows on launch
- Run button to trigger both DNS and SSL lookups simultaneously
- DNS and SSL results displayed in clearly separated sections below
- Each section loads independently — don't block SSL results waiting for DNS
  or vice versa

## Technical constraints
- SwiftUI, iOS only
- Fully offline except for DNS-over-HTTPS requests and SSL connections
- No accounts, no analytics, no ads
- No third-party dependencies — URLSession and Network framework only
- Targets latest iOS

### Recent searches
Store the last 20 searched domains locally using UserDefaults. Display them as
a tappable list below the text field when no results are showing. Tapping a
recent domain populates the text field and runs the lookup immediately. Include
a "Clear" button to wipe history. Most recent at the top.

### Share / export
A share button (SF Symbol: `square.and.arrow.up`) in the top-right of the
results area. Formats the full DNS and SSL results as plain text and presents
the iOS share sheet via ShareLink or UIActivityViewController. The export
should include the domain, timestamp, all DNS records with TTLs, and all SSL
cert fields.

## What good looks like
A developer pastes a domain, taps run, and within a couple of seconds sees a
clean breakdown of every DNS record type and the full SSL cert status. It should
feel like a native, polished version of running `dig` and `openssl s_client`
from the terminal.
