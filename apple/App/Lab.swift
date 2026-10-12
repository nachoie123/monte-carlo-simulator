import SwiftUI
import MonteCarloKit

/// El laboratorio: qué empresa, con qué mandos, y el resultado. Recalcula en segundo plano al tocar un mando.
@Observable @MainActor
final class Lab {
    static let bundled = MonteCarlo.bundledSeries()
    var series: [PriceSeries] = bundled + Store.load()
    var symbol: String = "AAPL" { didSet { schedule() } }
    var horizon: Horizon = .threeMonths { didSet { schedule() } }
    var block: Int = MonteCarlo.block { didSet { schedule() } }
    var nPaths: Int = MonteCarlo.nPaths { didSet { schedule() } }
    var seed: UInt64 = MonteCarlo.seed { didSet { schedule() } }
    var engineFilter: Engine? = nil   // nil = los dos

    private(set) var analysis: Analysis?
    private(set) var running = false
    private(set) var error: String?
    private(set) var adding = false
    private(set) var addError: String?
    private var task: Task<Void, Never>?

    static let blocks = [5, 21, 63]
    static let pathCounts = [1_000, 10_000]

    var selected: PriceSeries? { series.first { $0.symbol == symbol } }

    init() { schedule() }

    func reseed() { seed = UInt64.random(in: 1..<10_000) }

    func isDownloaded(_ symbol: String) -> Bool { !Self.bundled.contains { $0.symbol == symbol } }

    /// Buscador: baja la serie de Yahoo (`Yahoo.resolve`), la guarda y la selecciona. Si ya está en la lista, solo la selecciona.
    func add(_ query: String) async {
        adding = true; addError = nil
        defer { adding = false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let known = series.first(where: { $0.symbol.caseInsensitiveCompare(q) == .orderedSame }) { symbol = known.symbol; return }
        do {
            let s = try await Yahoo.resolve(q)
            series.removeAll { $0.symbol == s.symbol && isDownloaded($0.symbol) }
            if !series.contains(where: { $0.symbol == s.symbol }) { series.append(s); Store.save(s) }
            symbol = s.symbol
        } catch Yahoo.Failure.notFound, Yahoo.Failure.badResponse {
            addError = Copy.current.notFound(q)
        } catch {
            addError = error.localizedDescription   // sin red, tiempo agotado…: el sistema ya lo dice en su idioma
        }
    }

    func remove(_ sym: String) {
        guard isDownloaded(sym) else { return }
        series.removeAll { $0.symbol == sym }
        Store.delete(sym)
        if symbol == sym { symbol = series.first!.symbol }
    }

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

/// Series bajadas de Yahoo, un JSON por empresa en Application Support (las 5 de fábrica viven en el paquete).
enum Store {
    static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appending(path: "com.nachosanbenito.montecarlo/prices")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static func file(_ sym: String) -> URL { dir.appending(path: sym + ".json") }
    static func load() -> [PriceSeries] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files.sorted { ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) < ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
            .compactMap { try? JSONDecoder().decode(PriceSeries.self, from: Data(contentsOf: $0)) }
    }
    static func save(_ s: PriceSeries) { try? JSONEncoder().encode(s).write(to: file(s.symbol), options: .atomic) }
    static func delete(_ sym: String) { try? FileManager.default.removeItem(at: file(sym)) }
}
