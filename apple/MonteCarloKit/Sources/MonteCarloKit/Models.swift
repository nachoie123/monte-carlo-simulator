import Foundation

public enum Horizon: String, CaseIterable, Codable, Sendable, Identifiable {
    case oneMonth = "1m", threeMonths = "3m", oneYear = "1y"
    public var id: String { rawValue }
    /// Días de bolsa.
    public var days: Int { switch self { case .oneMonth: 21; case .threeMonths: 63; case .oneYear: 252 } }
}

public enum Engine: String, CaseIterable, Codable, Sendable, Identifiable {
    case gbm, bootstrap
    public var id: String { rawValue }
}

/// Precios ajustados de una acción (lo que `load()` saca de Yahoo). Es el único dato de entrada.
public struct PriceSeries: Codable, Sendable, Equatable {
    public var symbol: String
    public var name: String
    public var currency: String
    public var dates: [String]   // "YYYY-MM-DD"
    public var close: [Double]

    public init(symbol: String, name: String, currency: String, dates: [String], close: [Double]) {
        self.symbol = symbol; self.name = name; self.currency = currency; self.dates = dates; self.close = close
    }
}

/// Cuánto se aleja la realidad de la campana.
public struct Tails: Sendable, Equatable {
    public var nDays: Int
    public var excessKurtosis: Double
    public var crashDaysReal: Int
    public var crashDaysNormal: Double
    public var worstDay: Double
    public var histMid: [Double]
    public var histReal: [Int]
    public var histNormal: [Double]
}

/// Cono, cifras de riesgo y caminos de muestra de un motor.
public struct EngineSummary: Sendable, Equatable {
    public var bands: [Int: [Double]]   // percentil (5, 25, 50, 75, 95) -> precio por día (días+1)
    public var samples: [[Double]]      // 40 caminos
    public var median: Double
    public var pUp: Double
    public var var95: Double
    public var es95: Double
    public var maxDDMedian: Double
    public var hist: [Int] = []
    var terminal: [Double] = []
}

public struct Simulation: Sendable, Equatable {
    public var engines: [Engine: EngineSummary]
    public var histEdges: [Double]
    public subscript(_ e: Engine) -> EngineSummary { engines[e]! }
}

public struct EngineExam: Sendable, Equatable {
    public var pit: [Double]
    public var coverage: [Double: Double]   // nivel prometido -> cobertura real
    public var missLow: Double
    public var missHigh: Double
}

public struct Exam: Sendable, Equatable {
    public var origins: Int
    public var independent: Double
    public var dates: [String]
    public var engines: [Engine: EngineExam]
    public subscript(_ e: Engine) -> EngineExam { engines[e]! }
}

public struct Analysis: Sendable, Equatable {
    public var symbol: String
    public var name: String
    public var currency: String
    public var horizon: Horizon
    public var days: Int
    public var s0: Double
    public var lastDate: String
    public var historyFrom: String
    public var muAnnual: Double
    public var sigmaAnnual: Double
    public var tails: Tails
    public var sim: Simulation
    public var exam: Exam
    public var nPaths: Int
}

public enum MonteCarloError: LocalizedError, Equatable {
    case noData(String)
    case shortHistory(String, days: Int)
    case unreliable(String)

    public var errorDescription: String? {
        switch self {
        case .noData(let t): String(localized: "No data for '\(t)'.", bundle: .module)
        case .shortHistory(let t, let d): String(localized: "'\(t)' has too little history (\(d) days; about 6.5 years are needed).", bundle: .module)
        case .unreliable(let t): String(localized: "'\(t)': unreliable series (flat days or impossible jumps).", bundle: .module)
        }
    }
}
