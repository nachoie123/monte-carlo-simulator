import SwiftUI
import MonteCarloKit

/// El laboratorio: qué empresa, con qué mandos, y el resultado. Recalcula en segundo plano al tocar un mando.
@Observable @MainActor
final class Lab {
    var series: [PriceSeries] = MonteCarlo.bundledSeries()
    var symbol: String = "AAPL" { didSet { schedule() } }
    var horizon: Horizon = .threeMonths { didSet { schedule() } }
    var block: Int = MonteCarlo.block { didSet { schedule() } }
    var nPaths: Int = MonteCarlo.nPaths { didSet { schedule() } }
    var seed: UInt64 = MonteCarlo.seed { didSet { schedule() } }
    var engineFilter: Engine? = nil   // nil = los dos

    private(set) var analysis: Analysis?
    private(set) var running = false
    private(set) var error: String?
    private var task: Task<Void, Never>?

    static let blocks = [5, 21, 63]
    static let pathCounts = [1_000, 10_000]

    var selected: PriceSeries? { series.first { $0.symbol == symbol } }

    init() { schedule() }

    func reseed() { seed = UInt64.random(in: 1..<10_000) }

    func schedule() {
        task?.cancel()
        guard let s = selected else { return }
        let (h, b, n, seed) = (horizon, block, nPaths, self.seed)
        running = true; error = nil
        task = Task {
            try? await Task.sleep(for: .milliseconds(120))   // dos toques seguidos = un cálculo
            guard !Task.isCancelled else { return }
            let result: Result<Analysis, Error> = await Task.detached(priority: .userInitiated) {
                do { return .success(MonteCarlo.analyze(try MonteCarlo.clean(s), horizon: h, nPaths: n, seed: seed, block: b)) }
                catch { return .failure(error) }
            }.value
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let a): analysis = a
            case .failure(let e): self.error = e.localizedDescription
            }
            running = false
        }
    }
}
