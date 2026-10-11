import XCTest
@testable import MonteCarloKit

/// Los mismos 5 checks de `test_montecarlo.py`, sin red: fórmula del GBM y examen bien programado.
final class UnitTests: XCTestCase {
    let m = 0.0004, s = 0.015   // ~10% y ~24% anual

    func normals(_ n: Int, rng: inout SeededRNG) -> [Double] { (0..<n).map { _ in m + s * rng.normal() } }

    func testGBMMomentsMatchFormula() {
        var rng = SeededRNG(seed: 0)
        let r = normals(5000, rng: &rng)
        let x = MonteCarlo.simGBM(r, days: 252, n: 20_000, rng: &rng)
        let sums = (0..<20_000).map { p in (0..<252).reduce(0.0) { $0 + x[p * 252 + $1] } }
        XCTAssertEqual(Stats.mean(sums), 252 * Stats.mean(r), accuracy: 0.01)
        XCTAssertEqual(Stats.std(sums), 252.0.squareRoot() * Stats.std(r), accuracy: 0.01)
    }

    func testBootstrapUsesOnlyRealDays() {
        var rng = SeededRNG(seed: 0)
        let r = normals(5000, rng: &rng)
        let b = MonteCarlo.simBootstrap(r, days: 50, n: 100, rng: &rng)
        XCTAssertEqual(b.count, 100 * 50)
        let set = Set(r)
        XCTAssertTrue(b.allSatisfy { set.contains($0) })
    }

    func testExamOnBellDataCoversWhatItPromises() {
        var rng = SeededRNG(seed: 0)
        let ex = MonteCarlo.exam(normals(6000, rng: &rng), days: 21)
        for e in Engine.allCases { XCTAssertEqual(ex[e].coverage[0.9]!, 0.90, accuracy: 0.06, "\(e)") }
    }

    func testFatTailsGBMNotBetterThanBootstrap() {
        var rng = SeededRNG(seed: 0)
        // t de Student con 3 g.l. = normal / sqrt(chi2_3 / 3)
        let fat = (0..<6000).map { _ -> Double in
            let z = rng.normal(); let c = (0..<3).reduce(0.0) { acc, _ in let v = rng.normal(); return acc + v * v }
            return z / (c / 3).squareRoot() * s / 3.0.squareRoot() + m
        }
        let ex = MonteCarlo.exam(fat, days: 1, step: 5)
        XCTAssertGreaterThanOrEqual(ex[.bootstrap].coverage[0.95]!, ex[.gbm].coverage[0.95]! - 0.01)
    }

    func testGBMSimulationMatchesClosedForm() {
        var rng = SeededRNG(seed: 0)
        let w = normals(1260, rng: &rng)
        let sim = MonteCarlo.simulate(w, s0: 100, days: 63)[.gbm]
        let z = Stats.mean(w) * 63 / (Stats.std(w) * 63.0.squareRoot())
        XCTAssertEqual(sim.pUp, Stats.phi(z), accuracy: 0.015)
        XCTAssertEqual(sim.median / (100 * exp(Stats.mean(w) * 63)), 1, accuracy: 0.01)
    }

    func testPercentileAndHistogramLikeNumpy() {
        XCTAssertEqual(Stats.percentile(sorted: [1, 2, 3, 4], 50), 2.5)
        XCTAssertEqual(Stats.percentile(sorted: [10, 20, 30], 5), 11, accuracy: 1e-12)
        XCTAssertEqual(Stats.histogram([0, 0.5, 1, 1.5, 2, 2.5], edges: [0, 1, 2]), [2, 3])   // 2.5 fuera; 2 en el último
        XCTAssertEqual(Stats.linspace(-6, 6, 49).count, 49)
        XCTAssertEqual(Stats.phi(0), 0.5, accuracy: 1e-15)
    }
}
