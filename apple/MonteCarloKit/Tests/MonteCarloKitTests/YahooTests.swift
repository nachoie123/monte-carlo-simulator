import XCTest
@testable import MonteCarloKit

/// Parseo de las dos respuestas de Yahoo sin tocar la red (muestras reales recortadas del 12/10/2026).
final class YahooTests: XCTestCase {
    func testSearchKeepsOnlyEquityAndETF() {
        let json = #"{"quotes":[{"symbol":"AAPL","quoteType":"EQUITY","shortname":"Apple Inc."},{"symbol":"SAAPL=F","quoteType":"FUTURE"},{"symbol":"SPY","quoteType":"ETF","longname":"SPDR S&P 500"}]}"#
        let hits = Yahoo.parseSearch(Data(json.utf8), limit: 8)
        XCTAssertEqual(hits, [.init(symbol: "AAPL", name: "Apple Inc."), .init(symbol: "SPY", name: "SPDR S&P 500")])
    }

    func testChartDatesFollowExchangeAndSkipNulls() throws {
        // 2001-05-31 22:00 UTC es 2001-06-01 en Madrid (gmtoffset 7200); el segundo día viene sin dato.
        let json = #"{"chart":{"result":[{"meta":{"symbol":"ITX.MC","currency":"EUR","longName":"Inditex","gmtoffset":7200},"timestamp":[991346400,991432800,991519200],"indicators":{"quote":[{"volume":[100,null,300]}],"adjclose":[{"adjclose":[10.0,null,12.0]}]}}]}}"#
        let (s, traded) = try Yahoo.parseChart(Data(json.utf8), symbol: "ITX.MC")
        XCTAssertEqual(s.dates, ["2001-06-01", "2001-06-03"])
        XCTAssertEqual(s.close, [10, 12])
        XCTAssertEqual(s.currency, "EUR"); XCTAssertEqual(s.name, "Inditex")
        XCTAssertEqual(traded, 300 * 12)   // mediana de [100, 300] = el de arriba × último cierre
    }

    func testChartWithoutResultThrows() {
        XCTAssertThrowsError(try Yahoo.parseChart(Data(#"{"chart":{"result":null,"error":{"code":"Not Found"}}}"#.utf8), symbol: "ZZZZ"))
    }
}
