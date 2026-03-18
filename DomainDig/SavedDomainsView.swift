import SwiftUI

struct SavedDomainsView: View {
    @Bindable var viewModel: DomainViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if viewModel.savedDomains.isEmpty {
                Text("No saved domains")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color(.systemGray6).opacity(0.5))
            } else {
                ForEach(viewModel.savedDomains, id: \.self) { domain in
                    Button {
                        viewModel.domain = domain
                        dismiss()
                        viewModel.run()
                    } label: {
                        Text(domain)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .listRowBackground(Color(.systemGray6).opacity(0.5))
                }
                .onDelete { offsets in
                    viewModel.removeSavedDomains(at: offsets)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Saved Domains")
        .toolbar {
            if !viewModel.savedDomains.isEmpty {
                EditButton()
            }
        }
        .preferredColorScheme(.dark)
    }
}
