import SwiftUI
import MonteCarloKit

@main
struct MonteCarloApp: App {
    @State private var lab = Lab()

    var body: some Scene {
        WindowGroup {
            ContentView(lab: lab)
                #if os(macOS)
                .frame(minWidth: 820, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 780)
        #endif
    }
}

/// Lista de empresas a la izquierda, historia a la derecha. En iPhone se abre directamente en la historia.
struct ContentView: View {
    @Bindable var lab: Lab
    @State private var column = NavigationSplitViewColumn.detail
    @State private var query = ""
    let t = Copy.current

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $column) {
            List(selection: Binding(get: { Optional(lab.symbol) }, set: { if let s = $0 { lab.symbol = s; column = .detail } })) {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(t.addPrompt, text: $query)
                            .textFieldStyle(.plain).autocorrectionDisabled().submitLabel(.search)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .onSubmit(submit)
                        if lab.adding { ProgressView().controlSize(.small) }
                    }
                    Text(lab.addError ?? t.addHint).font(.caption).foregroundStyle(lab.addError == nil ? Theme.muted : Theme.bad)
                        .fixedSize(horizontal: false, vertical: true)   // el pie de sección no se pinta en la barra lateral del Mac
                }
                Section {
                    ForEach(lab.series, id: \.symbol) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(.body.weight(.medium)).lineLimit(1)
                                Text(s.symbol).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Fmt.money(s.close.last ?? 0, s.currency)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions { if lab.isDownloaded(s.symbol) { Button(t.remove, role: .destructive) { lab.remove(s.symbol) } } }
                        .contextMenu { if lab.isDownloaded(s.symbol) { Button(t.remove, role: .destructive) { lab.remove(s.symbol) } } }
                    }
                }
            }
            .navigationTitle(t.companies)
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
            #endif
        } detail: {
            StoryView(lab: lab)
        }
        .tint(Theme.gbm)
    }

    private func submit() {
        let q = query
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty, !lab.adding else { return }
        Task { await lab.add(q); if lab.addError == nil { query = ""; column = .detail } }
    }
}
