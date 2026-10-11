import Foundation

/// Generador con semilla (SplitMix64). numpy usa PCG64: las secuencias no coinciden, por eso los
/// tests comparan lo aleatorio con tolerancia y lo determinista al dígito.
public struct SeededRNG {
    var state: UInt64
    var spare: Double? = nil

    public init(seed: UInt64) { state = seed }

    @inline(__always) mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniforme en [0, 1).
    @inline(__always) mutating func uniform() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Entero en 0..<n. ponytail: sesgo de módulo despreciable (n ≤ 5.000 frente a 2^64).
    @inline(__always) mutating func int(below n: Int) -> Int { Int(next() % UInt64(n)) }

    /// Normal estándar por Box-Muller, guardando la segunda muestra.
    @inline(__always) mutating func normal() -> Double {
        if let s = spare { spare = nil; return s }
        var u1 = uniform()
        while u1 <= 0 { u1 = uniform() }
        let u2 = uniform()
        let rad = (-2 * log(u1)).squareRoot(), ang = 2 * Double.pi * u2
        spare = rad * sin(ang)
        return rad * cos(ang)
    }
}

enum Stats {
    /// CDF de la normal estándar (sin scipy): mismo `phi` que montecarlo.py.
    static func phi(_ x: Double) -> Double { 0.5 * erfc(-x / 2.0.squareRoot()) }

    static func mean(_ x: [Double]) -> Double { x.reduce(0, +) / Double(x.count) }

    /// Desviación típica muestral (ddof = 1), dos pasadas como numpy.
    static func std(_ x: [Double], mean m: Double? = nil) -> Double {
        let m = m ?? mean(x)
        var acc = 0.0
        for v in x { let d = v - m; acc += d * d }
        return (acc / Double(x.count - 1)).squareRoot()
    }

    /// Percentil con interpolación lineal (el `np.percentile` por defecto). `sorted` ya ordenado.
    static func percentile(sorted s: [Double], _ p: Double) -> Double {
        let idx = Double(s.count - 1) * p / 100
        let lo = Int(idx.rounded(.down)), hi = min(lo + 1, s.count - 1)
        let g = idx - Double(lo)
        return s[lo] * (1 - g) + s[hi] * g
    }

    static func linspace(_ a: Double, _ b: Double, _ n: Int) -> [Double] {
        let step = (b - a) / Double(n - 1)
        var out = (0..<n).map { a + Double($0) * step }
        out[n - 1] = b
        return out
    }

    /// `np.histogram(values, edges)`: bins [e_i, e_i+1), el último cerrado; fuera de rango no cuenta.
    static func histogram(_ values: [Double], edges: [Double]) -> [Int] {
        let bins = edges.count - 1
        var counts = [Int](repeating: 0, count: bins)
        let first = edges[0], last = edges[bins]
        for v in values {
            if v < first || v > last || v.isNaN { continue }
            if v == last { counts[bins - 1] += 1; continue }
            var lo = 0, hi = bins   // mayor i con edges[i] <= v
            while hi - lo > 1 { let mid = (lo + hi) / 2; if edges[mid] <= v { lo = mid } else { hi = mid } }
            counts[lo] += 1
        }
        return counts
    }
}
