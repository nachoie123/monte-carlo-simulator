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
    let t = Copy.current

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $column) {
            List(lab.series, id: \.symbol, selection: Binding(get: { Optional(lab.symbol) }, set: { if let s = $0 { lab.symbol = s; column = .detail } })) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.body.weight(.medium))
                        Text(s.symbol).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Fmt.money(s.close.last ?? 0, s.currency)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
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
}
