import XCTest
@testable import MonteCarloKit

/// El Swift tiene que dar los MISMOS números que `montecarlo.py` con los mismos precios.
/// Lo determinista (μ, σ, colas, PIT del GBM, fechas) al dígito; lo aleatorio (10.000 caminos,
/// bootstrap) dentro del error de muestreo, porque numpy y Swift no comparten generador.
final class PythonParityTests: XCTestCase {
    struct Expected: Decodable {
        struct Tails: Decodable { let nDays: Int; let excessKurtosis: Double; let crashDaysReal: Int; let crashDaysNormal: Double; let worstDay: Double; let hist: Hist }
        struct Hist: Decodable { let mid: [Double]; let real: [Int]; let normal: [Double] }
        struct Eng: Decodable { let bands: [String: [Double]]; let median: Double; let pUp: Double; let var95: Double; let es95: Double; let maxDdMedian: Double; let hist: [Int] }
        struct Sim: Decodable { let gbm: Eng; let bootstrap: Eng; let histEdges: [Double] }
        struct ExEng: Decodable { let pit: [Double]; let coverage: [String: Double]; let missLow: Double; let missHigh: Double }
        struct Ex: Decodable { let origins: Int; let independent: Double; let dates: [String]; let gbm: ExEng; let bootstrap: ExEng }
        let s0: Double; let days: Int; let muAnnual: Double; let sigmaAnnual: Double; let tails: Tails; let sim: Sim; let exam: Ex
    }

    static let series: [String: PriceSeries] = Dictionary(uniqueKeysWithValues: MonteCarlo.bundledSeries().map { ($0.symbol, $0) })

    func expected(_ sym: String, _ h: Horizon) throws -> Expected {
        let url = Bundle.module.url(forResource: "\(sym)-\(h.rawValue)", withExtension: "json", subdirectory: "Expected")!
        let dec = JSONDecoder(); dec.keyDecodingStrategy = .convertFromSnakeCase
        return try dec.decode(Expected.self, from: Data(contentsOf: url))
    }

    func testBundledSeriesLoad() {
        XCTAssertEqual(Self.series.keys.sorted(), ["AAPL", "ITX.MC", "NVDA", "REP.MC", "SPY"])
        XCTAssertNoThrow(try MonteCarlo.clean(Self.series["AAPL"]!))
    }

    func check(_ sym: String, _ h: Horizon) throws {
        let e = try expected(sym, h)
        let a = MonteCarlo.analyze(try MonteCarlo.clean(Self.series[sym]!), horizon: h)
        let tag = "\(sym) \(h.rawValue)"

        // --- determinista: al dígito ---
        XCTAssertEqual(a.s0, e.s0, tag); XCTAssertEqual(a.days, e.days, tag)
        XCTAssertEqual(a.muAnnual, e.muAnnual, accuracy: 1e-9, tag)
        XCTAssertEqual(a.sigmaAnnual, e.sigmaAnnual, accuracy: 1e-9, tag)
        XCTAssertEqual(a.tails.nDays, e.tails.nDays, tag)
        XCTAssertEqual(a.tails.excessKurtosis, e.tails.excessKurtosis, accuracy: 1e-8, tag)
        XCTAssertEqual(a.tails.crashDaysReal, e.tails.crashDaysReal, tag)
        XCTAssertEqual(a.tails.crashDaysNormal, e.tails.crashDaysNormal, accuracy: 1e-9, tag)
        XCTAssertEqual(a.tails.worstDay, e.tails.worstDay, accuracy: 1e-12, tag)
        XCTAssertEqual(a.tails.histReal, e.tails.hist.real, tag)
        zip(a.tails.histMid, e.tails.hist.mid).forEach { XCTAssertEqual($0, $1, accuracy: 5e-4, tag) }
        zip(a.tails.histNormal, e.tails.hist.normal).forEach { XCTAssertEqual($0, $1, accuracy: 5e-3, tag) }

        XCTAssertEqual(a.exam.origins, e.exam.origins, tag)
        XCTAssertEqual(a.exam.independent, e.exam.independent, tag)
        XCTAssertEqual(a.exam.dates, e.exam.dates, tag)
        let g = a.exam[.gbm]
        XCTAssertEqual(g.pit.count, e.exam.gbm.pit.count, tag)
        zip(g.pit, e.exam.gbm.pit).forEach { XCTAssertEqual($0, $1, accuracy: 6e-5, tag) }   // Python los guarda con 4 decimales
        let tol = 1.5 / Double(e.exam.origins)   // un origen justo en el borde de una franja
        for (L, c) in e.exam.gbm.coverage { XCTAssertEqual(g.coverage[Double(L)!]!, c, accuracy: tol, "\(tag) gbm cov \(L)") }
        XCTAssertEqual(g.missLow, e.exam.gbm.missLow, accuracy: tol, tag)
        XCTAssertEqual(g.missHigh, e.exam.gbm.missHigh, accuracy: tol, tag)

        // --- aleatorio: dentro del error de muestreo ---
        let b = a.exam[.bootstrap]
        for (L, c) in e.exam.bootstrap.coverage { XCTAssertEqual(b.coverage[Double(L)!]!, c, accuracy: 0.06, "\(tag) boot cov \(L)") }
        XCTAssertEqual(b.missLow, e.exam.bootstrap.missLow, accuracy: 0.04, tag)
        XCTAssertEqual(b.missHigh, e.exam.bootstrap.missHigh, accuracy: 0.04, tag)

        for (eng, ex, slack) in [(Engine.gbm, e.sim.gbm, 1.0), (.bootstrap, e.sim.bootstrap, 1.6)] {
            let s = a.sim[eng]; let t = "\(tag) \(eng)"
            XCTAssertEqual(s.median / ex.median, 1, accuracy: 0.012 * slack, t)
            XCTAssertEqual(s.pUp, ex.pUp, accuracy: 0.015 * slack, t)
            XCTAssertEqual(s.var95, ex.var95, accuracy: 0.012 * slack, t)
            XCTAssertEqual(s.es95, ex.es95, accuracy: 0.02 * slack, t)
            XCTAssertEqual(s.maxDDMedian, ex.maxDdMedian, accuracy: 0.012 * slack, t)
            for p in MonteCarlo.bands {
                let mine = s.bands[p]!, theirs = ex.bands[String(p)]!
                XCTAssertEqual(mine.count, theirs.count, t)
                XCTAssertEqual(mine.last! / theirs.last!, 1, accuracy: (p == 5 || p == 95 ? 0.03 : 0.015) * slack, "\(t) band \(p)")
            }
            XCTAssertEqual(s.samples.count, 40, t); XCTAssertEqual(s.samples[0].count, e.days + 1, t)
            XCTAssertEqual(s.hist.count, 40, t)
        }
        XCTAssertEqual(a.sim.histEdges.count, 41, tag)
    }

    func testAAPL1m() throws { try check("AAPL", .oneMonth) }
    func testAAPL3m() throws { try check("AAPL", .threeMonths) }
    func testAAPL1y() throws { try check("AAPL", .oneYear) }
    func testITX1m() throws { try check("ITX.MC", .oneMonth) }
    func testITX3m() throws { try check("ITX.MC", .threeMonths) }
    func testITX1y() throws { try check("ITX.MC", .oneYear) }
    func testNVDA1m() throws { try check("NVDA", .oneMonth) }
    func testNVDA3m() throws { try check("NVDA", .threeMonths) }
    func testNVDA1y() throws { try check("NVDA", .oneYear) }
    func testREP1m() throws { try check("REP.MC", .oneMonth) }
    func testREP3m() throws { try check("REP.MC", .threeMonths) }
    func testREP1y() throws { try check("REP.MC", .oneYear) }
    func testSPY1m() throws { try check("SPY", .oneMonth) }
    func testSPY3m() throws { try check("SPY", .threeMonths) }
    func testSPY1y() throws { try check("SPY", .oneYear) }
}
