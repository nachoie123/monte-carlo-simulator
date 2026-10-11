import Foundation

/// Port 1:1 de `montecarlo.py`. Mismas constantes, mismas fórmulas, mismo orden de cálculo.
///
///   gbm        S_T = S_0 · exp((μ − σ²/2)·T + σ·√T·Z),  Z ~ N(0, 1): cada día sale de una campana
///   bootstrap  bloques de 21 días reales del pasado, en orden aleatorio
///   examen     el simulador se coloca en fechas pasadas (una cada 21 días), se calibra con los 5 años
///              anteriores y se mira dónde cayó el precio real dentro de lo simulado (PIT)
public enum MonteCarlo {
    public static let cal = 1260          // 5 años de bolsa
    public static let block = 21
    public static let nPaths = 10_000
    public static let nExam = 2_000
    public static let step = 21
    public static let yearsMax = 20
    public static let seed: UInt64 = 7
    public static let bands = [5, 25, 50, 75, 95]
    public static let levels = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95]

    // MARK: motores: rendimientos diarios en log, plano, fila = camino

    static func simGBM(_ r: [Double], days: Int, n: Int, rng: inout SeededRNG) -> [Double] {
        let m = Stats.mean(r), s = Stats.std(r, mean: m)
        var out = [Double](repeating: 0, count: n * days)
        for i in 0..<out.count { out[i] = m + s * rng.normal() }
        return out
    }

    static func simBootstrap(_ r: [Double], days: Int, n: Int, rng: inout SeededRNG, block: Int = block) -> [Double] {
        let k = (days + block - 1) / block
        let range = r.count - block + 1
        var out = [Double](repeating: 0, count: n * days)
        r.withUnsafeBufferPointer { rp in
            out.withUnsafeMutableBufferPointer { op in
                for p in 0..<n {
                    let base = p * days
                    for j in 0..<k {
                        let start = rng.int(below: range)
                        let from = j * block, to = min(from + block, days)
                        for d in from..<to { op[base + d] = rp[start + d - from] }
                    }
                }
            }
        }
        return out
    }

    // MARK: datos

    /// Lo que hace `load()` tras bajar de Yahoo: positivos, últimos 20 años, histórico suficiente y serie fiable.
    public static func clean(_ s: PriceSeries) throws -> PriceSeries {
        var pairs = zip(s.dates, s.close).filter { $0.1 > 0 && $0.1.isFinite }
        guard let last = pairs.last else { throw MonteCarloError.noData(s.symbol) }
        let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withFullDate]
        if let lastDate = fmt.date(from: last.0) {
            let cutoff = lastDate.addingTimeInterval(-Double(365 * yearsMax) * 86_400)
            pairs = pairs.filter { fmt.date(from: $0.0).map { $0 >= cutoff } ?? true }
        }
        if pairs.count < cal + Horizon.oneYear.days + 10 * step {
            throw MonteCarloError.shortHistory(s.symbol, days: pairs.count)
        }
        let close = pairs.map(\.1)
        let r = logReturns(close).suffix(cal)
        let zeros = Double(r.filter { $0 == 0 }.count) / Double(r.count)
        if zeros > 0.10 || r.map(abs).max()! > 0.7 { throw MonteCarloError.unreliable(s.symbol) }
        return PriceSeries(symbol: s.symbol, name: s.name, currency: s.currency, dates: pairs.map(\.0), close: close)
    }

    public static func logReturns(_ close: [Double]) -> [Double] {
        (1..<close.count).map { log(close[$0] / close[$0 - 1]) }
    }

    /// Las 5 empresas de fábrica (precios dentro del paquete, sacados por `fixtures/make_fixtures.py`).
    public static func bundledSeries() -> [PriceSeries] {
        guard let dir = Bundle.module.url(forResource: "prices", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        let order = ["AAPL", "ITX.MC", "NVDA", "REP.MC", "SPY"]
        return files.compactMap { try? JSONDecoder().decode(PriceSeries.self, from: Data(contentsOf: $0)) }
            .sorted { (order.firstIndex(of: $0.symbol) ?? 99) < (order.firstIndex(of: $1.symbol) ?? 99) }
    }

    // MARK: análisis

    public static func fatTails(_ r: [Double]) -> Tails {
        let m = Stats.mean(r), s = Stats.std(r, mean: m)
        let z = r.map { ($0 - m) / s }
        let edges = Stats.linspace(-6, 6, 49)
        let counts = Stats.histogram(z.map { min(max($0, -6), 6) }, edges: edges)
        let mid = (0..<48).map { (edges[$0] + edges[$0 + 1]) / 2 }
        let width = edges[1] - edges[0]
        let normal = mid.map { Double(z.count) * width * exp(-$0 * $0 / 2) / (2 * Double.pi).squareRoot() }
        return Tails(
            nDays: r.count,
            excessKurtosis: Stats.mean(z.map { $0 * $0 * $0 * $0 }) - 3,
            crashDaysReal: z.filter { abs($0) > 4 }.count,
            crashDaysNormal: Double(z.count) * 2 * Stats.phi(-4),
            worstDay: expm1(r.min()!),
            histMid: mid, histReal: counts, histNormal: normal)
    }

    /// `paths`: n filas de (días+1) precios, plano.
    static func summarize(_ paths: [Double], n: Int, cols: Int, s0: Double) -> EngineSummary {
        let term = (0..<n).map { paths[$0 * cols + cols - 1] }
        let ret = term.map { $0 / s0 - 1 }
        let sortedRet = ret.sorted()
        let q5 = Stats.percentile(sorted: sortedRet, 5)
        var bands = [Int: [Double]](); for p in self.bands { bands[p] = [Double](repeating: 0, count: cols) }
        var col = [Double](repeating: 0, count: n)
        for c in 0..<cols {
            for i in 0..<n { col[i] = paths[i * cols + c] }
            col.sort()
            for p in self.bands { bands[p]![c] = Stats.percentile(sorted: col, Double(p)) }
        }
        var dd = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var peak = -Double.infinity, worst = 0.0
            for c in 0..<cols { let v = paths[i * cols + c]; peak = max(peak, v); worst = max(worst, 1 - v / peak) }
            dd[i] = worst
        }
        let tail = ret.filter { $0 <= q5 }
        return EngineSummary(
            bands: bands,
            samples: (0..<min(40, n)).map { Array(paths[($0 * cols)..<($0 * cols + cols)]) },
            median: Stats.percentile(sorted: term.sorted(), 50),
            pUp: Double(ret.filter { $0 > 0 }.count) / Double(n),
            var95: -q5,
            es95: -Stats.mean(tail),
            maxDDMedian: Stats.percentile(sorted: dd.sorted(), 50),
            terminal: term)
    }

    public static func simulate(_ r: [Double], s0: Double, days: Int, n: Int = nPaths, seed: UInt64 = seed, block: Int = block) -> Simulation {
        var rng = SeededRNG(seed: seed)
        var out = [Engine: EngineSummary]()
        let cols = days + 1
        for eng in Engine.allCases {
            let logr = eng == .gbm ? simGBM(r, days: days, n: n, rng: &rng) : simBootstrap(r, days: days, n: n, rng: &rng, block: block)
            var paths = [Double](repeating: s0, count: n * cols)
            for i in 0..<n {
                var acc = 0.0
                for d in 0..<days { acc += logr[i * days + d]; paths[i * cols + d + 1] = s0 * exp(acc) }
            }
            out[eng] = summarize(paths, n: n, cols: cols, s0: s0)
        }
        let both = (out[.gbm]!.terminal + out[.bootstrap]!.terminal).sorted()
        let edges = Stats.linspace(Stats.percentile(sorted: both, 0.5), Stats.percentile(sorted: both, 99.5), 41)
        for eng in Engine.allCases {
            out[eng]!.hist = Stats.histogram(out[eng]!.terminal, edges: edges)
            out[eng]!.terminal = []
        }
        return Simulation(engines: out, histEdges: edges)
    }

    /// Backtest de calibración sobre la suma de log-rendimientos (equivale a comparar precios).
    /// `dates`: fecha del cierre t para cada origen (r[t] parte del cierre t).
    public static func exam(_ r: [Double], days: Int, dates: [String]? = nil, cal: Int = cal, step: Int = step,
                            n: Int = nExam, seed: UInt64 = seed, block: Int = block) -> Exam {
        var rng = SeededRNG(seed: seed)
        var pitG = [Double](), pitB = [Double](), origins = [Int]()
        var t = cal
        while t <= r.count - days {
            let w = Array(r[(t - cal)..<t])
            let real = r[t..<(t + days)].reduce(0, +)
            let m = Stats.mean(w), s = Stats.std(w, mean: m)
            pitG.append(Stats.phi((real - Double(days) * m) / (s * Double(days).squareRoot())))
            let sim = simBootstrap(w, days: days, n: n, rng: &rng, block: block)
            var below = 0
            for p in 0..<n {
                var acc = 0.0
                for d in 0..<days { acc += sim[p * days + d] }
                if acc < real { below += 1 }
            }
            pitB.append(Double(below) / Double(n))
            origins.append(t)
            t += step
        }
        func summary(_ p: [Double]) -> EngineExam {
            var cov = [Double: Double]()
            for L in levels { cov[L] = Double(p.filter { abs($0 - 0.5) <= L / 2 }.count) / Double(p.count) }
            return EngineExam(pit: p, coverage: cov,
                              missLow: Double(p.filter { $0 < 0.05 }.count) / Double(p.count),
                              missHigh: Double(p.filter { $0 > 0.95 }.count) / Double(p.count))
        }
        return Exam(origins: origins.count,
                    independent: (Double(origins.count) * Double(step) / Double(days) * 10).rounded() / 10,
                    dates: dates.map { d in origins.map { d[$0] } } ?? [],
                    engines: [.gbm: summary(pitG), .bootstrap: summary(pitB)])
    }

    /// `analyze()` de montecarlo.py a partir de una serie ya limpia (`clean`).
    public static func analyze(_ s: PriceSeries, horizon: Horizon, nPaths: Int = nPaths, seed: UInt64 = seed, block: Int = block) -> Analysis {
        let days = horizon.days
        let r = logReturns(s.close)
        let w = Array(r.suffix(cal))
        let s0 = s.close.last!
        let m = Stats.mean(w), sd = Stats.std(w, mean: m)
        return Analysis(
            symbol: s.symbol, name: s.name, currency: s.currency, horizon: horizon, days: days,
            s0: s0, lastDate: s.dates.last!, historyFrom: s.dates.first!,
            muAnnual: m * 252 + sd * sd * 252 / 2,
            sigmaAnnual: sd * 252.0.squareRoot(),
            tails: fatTails(r),
            sim: simulate(w, s0: s0, days: days, n: nPaths, seed: seed, block: block),
            exam: exam(r, days: days, dates: s.dates, seed: seed, block: block),
            nPaths: nPaths)
    }
}
