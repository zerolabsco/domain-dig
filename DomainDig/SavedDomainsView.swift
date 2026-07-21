import SwiftUI

struct SavedDomainsView: View {
    @Bindable var viewModel: DomainViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if viewModel.savedDomains.isEmpty {
                Text("No saved domains")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color(.appTextSecondary))
                    .listRowBackground(Color(.appSurface))
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
                    .listRowBackground(Color(.appSurface))
                }
                .onDelete { offsets in
                    viewModel.removeSavedDomains(at: offsets)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .navigationTitle("Saved Domains")
        .toolbar {
            if !viewModel.savedDomains.isEmpty {
                EditButton()
            }
        }
    }
}
