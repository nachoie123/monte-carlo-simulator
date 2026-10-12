import Foundation

/// `load()`, `search_symbols()` y `resolve()` de montecarlo.py contra Yahoo Finance. Sin clave ni cuenta.
public enum Yahoo {
    public struct Hit: Sendable, Equatable { public let symbol: String, name: String }

    public enum Failure: Error, Equatable {
        case notFound(String)      // ninguna bolsa con histórico suficiente y datos limpios
        case badResponse(String)   // Yahoo contestó pero sin datos (ticker inexistente, 404…)
    }

    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 MonteCarloStockSimulator/1.0"]
        c.timeoutIntervalForRequest = 20
        return URLSession(configuration: c)
    }()

    static func get(_ url: String, what: String) async throws -> Data {
        let (data, resp) = try await session.data(from: URL(string: url)!)
        guard (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { throw Failure.badResponse(what) }
        return data
    }

    /// Acciones y ETF que Yahoo devuelve para un texto libre (`search_symbols`).
    public static func search(_ query: String, limit: Int = 8) async throws -> [Hit] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        let data = try await get("https://query2.finance.yahoo.com/v1/finance/search?q=\(q)&quotesCount=10&newsCount=0&listsCount=0", what: query)
        return parseSearch(data, limit: limit)
    }

    /// Serie diaria ajustada completa + dinero movido al día (mediana de 250 días × último cierre), como `load()`.
    public static func chart(_ symbol: String) async throws -> (series: PriceSeries, traded: Double) {
        let s = symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? symbol
        let now = Int(Date().timeIntervalSince1970)
        // `range=max` devuelve velas MENSUALES; con period1/period2 sí son diarias (es lo que pide yfinance).
        let data = try await get("https://query1.finance.yahoo.com/v8/finance/chart/\(s)?period1=0&period2=\(now)&interval=1d&events=div%2Csplits", what: symbol)
        return try parseChart(data, symbol: symbol)
    }

    /// `resolve()`: un ticker exacto se respeta; si es un nombre, de todas las bolsas que devuelve Yahoo
    /// se queda con la que más dinero mueve y pasa `clean`. Devuelve la serie ya limpia.
    public static func resolve(_ query: String) async throws -> PriceSeries {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { throw Failure.notFound(q) }
        if let exact = try? await chart(q.uppercased()).series, let clean = try? MonteCarlo.clean(exact) { return clean }
        let hits = try await search(q)
        let candidates: [(Double, PriceSeries)] = await withTaskGroup(of: (Double, PriceSeries)?.self) { group in
            for hit in hits {
                group.addTask {
                    guard let r = try? await chart(hit.symbol), let clean = try? MonteCarlo.clean(r.series) else { return nil }
                    return (r.traded, clean)
                }
            }
            return await group.reduce(into: []) { if let c = $1 { $0.append(c) } }
        }
        guard let best = candidates.max(by: { $0.0 < $1.0 }) else { throw Failure.notFound(q) }
        return best.1
    }

    // MARK: parsing (sin red, para poder probarlo)

    static func parseSearch(_ data: Data, limit: Int) -> [Hit] {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let quotes = root?["quotes"] as? [[String: Any]] ?? []
        return quotes.compactMap { q -> Hit? in
            guard let sym = q["symbol"] as? String, ["EQUITY", "ETF"].contains(q["quoteType"] as? String ?? "") else { return nil }
            return Hit(symbol: sym, name: (q["shortname"] as? String) ?? (q["longname"] as? String) ?? sym)
        }.prefix(limit).map { $0 }
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC"); f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    static func parseChart(_ data: Data, symbol: String) throws -> (series: PriceSeries, traded: Double) {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let result = ((root?["chart"] as? [String: Any])?["result"] as? [[String: Any]])?.first,
              let meta = result["meta"] as? [String: Any],
              let ts = result["timestamp"] as? [Double],
              let ind = result["indicators"] as? [String: Any],
              let adj = ((ind["adjclose"] as? [[String: Any]])?.first?["adjclose"] as? [Any]),
              let vol = ((ind["quote"] as? [[String: Any]])?.first?["volume"] as? [Any]),
              ts.count == adj.count else { throw Failure.badResponse(symbol) }
        let offset = (meta["gmtoffset"] as? Double) ?? 0   // la fecha es la de la bolsa, no la del usuario
        var dates: [String] = [], close: [Double] = []
        for (i, t) in ts.enumerated() {
            guard let c = adj[i] as? Double, c > 0 else { continue }   // Yahoo mete nulls en días sin dato
            dates.append(dayFormatter.string(from: Date(timeIntervalSince1970: t + offset)))
            close.append(c)
        }
        guard let last = close.last else { throw Failure.badResponse(symbol) }
        let volumes = vol.suffix(250).compactMap { $0 as? Double }.sorted()
        let traded = volumes.isEmpty ? 0 : volumes[volumes.count / 2] * last
        let name = (meta["longName"] as? String) ?? (meta["shortName"] as? String) ?? symbol
        return (PriceSeries(symbol: (meta["symbol"] as? String) ?? symbol, name: name,
                            currency: (meta["currency"] as? String) ?? "", dates: dates, close: close), traded)
    }
}
