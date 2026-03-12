import SwiftUI

struct ContentView: View {
    @State private var viewModel = DomainViewModel()
    @FocusState private var domainFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    inputSection
                    if viewModel.hasRun {
                        if viewModel.resultsLoaded {
                            HStack {
                                Spacer()
                                Button {
                                    shareResults()
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(.body))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 8)
                        }
                        dnsResultsSection
                        sslResultsSection
                    } else if !viewModel.recentSearches.isEmpty {
                        recentSearchesSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color.black)
            .navigationTitle("DomainDig")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .onAppear {
            domainFieldFocused = true
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 12) {
            TextField("e.g. cleberg.net", text: $viewModel.domain)
                .font(.system(.title3, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .focused($domainFieldFocused)
                .onSubmit { viewModel.run() }

            Button {
                domainFieldFocused = false
                viewModel.run()
            } label: {
                Text("Run")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.trimmedDomain.isEmpty)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Recent Searches

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    viewModel.clearRecentSearches()
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            ForEach(viewModel.recentSearches, id: \.self) { domain in
                Button {
                    viewModel.domain = domain
                    domainFieldFocused = false
                    viewModel.run()
                } label: {
                    Text(domain)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - DNS Results

    private var dnsResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DNS Records")

            if viewModel.dnsLoading {
                ProgressView("Querying DNS…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let error = viewModel.dnsError {
                errorLabel(error)
            } else {
                ForEach(viewModel.dnsSections) { section in
                    dnsRecordSection(section)
                }
            }
        }
        .padding(.top, 8)
    }

    private func dnsRecordSection(_ section: DNSSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.recordType.rawValue)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.cyan)

            if let error = section.error {
                errorLabel(error)
            } else if section.records.isEmpty {
                Text("No records found")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                dnsRecordRows(section.records)
            }

            // Wildcard sub-section (only shown when records exist)
            if !section.wildcardRecords.isEmpty {
                Text("*.\(viewModel.searchedDomain)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.cyan.opacity(0.7))
                    .padding(.top, 4)

                dnsRecordRows(section.wildcardRecords)
            }
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(6)
    }

    private func dnsRecordRows(_ records: [DNSRecord]) -> some View {
        ForEach(records) { record in
            HStack(alignment: .top) {
                Text(record.value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                Spacer()
                Text("TTL \(record.ttl)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - SSL Results

    private var sslResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SSL / TLS Certificate")

            if viewModel.sslLoading {
                ProgressView("Checking certificate…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let error = viewModel.sslError {
                errorLabel(error)
            } else if let info = viewModel.sslInfo {
                sslDetail(info)
            }
        }
        .padding(.top, 16)
    }

    private func sslDetail(_ info: SSLCertificateInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            certRow("Common Name", info.commonName)
            certRow("Issuer", info.issuer)

            // SANs
            VStack(alignment: .leading, spacing: 2) {
                Text("SANs")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                ForEach(info.subjectAltNames, id: \.self) { san in
                    Text(san)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            let formatter = DateFormatter.certDate
            certRow("Valid From", formatter.string(from: info.validFrom))
            certRow("Valid Until", formatter.string(from: info.validUntil))

            HStack {
                Text("Days Until Expiry")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(info.daysUntilExpiry)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(expiryColor(info.daysUntilExpiry))
            }

            certRow("Chain Depth", "\(info.chainDepth)")
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(6)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: .default))
            .foregroundStyle(.white)
    }

    private func certRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.red)
            .padding(8)
    }

    private func expiryColor(_ days: Int) -> Color {
        if days < 30 { return .red }
        if days < 60 { return .yellow }
        return .green
    }

    private func shareResults() {
        let text = viewModel.exportText()

        // Write to a named temp file so "Save to Files" uses a proper filename
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFmt.string(from: Date())
        let filename = "\(timestamp)_domaindigresults.txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        activityVC.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityVC, animated: true)
    }
}

private extension DateFormatter {
    static let certDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

#Preview {
    ContentView()
}
