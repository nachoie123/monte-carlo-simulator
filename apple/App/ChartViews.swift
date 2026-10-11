import SwiftUI
import Charts
import MonteCarloKit

/// Paso 1: la bolsa no es una campana. Barras de días reales (en σ) y la curva de lo que diría la normal.
struct TailsChart: View {
    let tails: Tails
    var body: some View {
        Chart {
            ForEach(Array(tails.histMid.enumerated()).filter { tails.histReal[$0.offset] > 0 }, id: \.offset) { i, mid in
                RectangleMark(xStart: .value("From", mid - 0.11), xEnd: .value("To", mid + 0.11),
                              yStart: .value("Floor", 0.5), yEnd: .value("Days", Double(tails.histReal[i])))
                    .foregroundStyle(abs(mid) > 4 ? Theme.bad : Theme.gbm.opacity(0.7))
            }
            ForEach(Array(tails.histMid.enumerated()), id: \.offset) { i, mid in
                LineMark(x: .value("σ", mid), y: .value("Normal", max(0.5, tails.histNormal[i])))
                    .foregroundStyle(Theme.ink).lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: 0.5...2000, type: .log)
        .chartXAxis { AxisMarks(values: [-6, -4, -2, 0, 2, 4, 6]) { v in
            AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))σ") } }
        } }
        .chartYAxis { AxisMarks(values: [1, 10, 100, 1000]) { AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel() } }
        .frame(height: 200)
    }
}

/// Paso 3: el cono. Franjas 5-95 y 25-75 por motor (AreaMark) y los 40 caminos de muestra dibujados en un Canvas
/// (20.000 puntos en LineMark serían lentos). `progress` 0→1 anima el dibujo de los caminos.
struct ConeChart: View {
    let sim: Simulation
    let s0: Double
    let filter: Engine?
    var progress: Double = 1

    var engines: [Engine] { filter.map { [$0] } ?? Engine.allCases }

    struct Band: Identifiable { let id: String; let group: String; let engine: Engine; let day: Int; let lo: Double; let hi: Double }
    struct Pt: Identifiable { let id: String; let engine: Engine; let day: Int; let v: Double }
    var bands: [Band] {
        var out = [Band]()
        for e in engines {
            let s = sim[e]
            for d in 0..<s.bands[50]!.count {
                out.append(Band(id: "\(e.rawValue)-90-\(d)", group: "\(e.rawValue)-90", engine: e, day: d, lo: s.bands[5]![d], hi: s.bands[95]![d]))
                out.append(Band(id: "\(e.rawValue)-50-\(d)", group: "\(e.rawValue)-50", engine: e, day: d, lo: s.bands[25]![d], hi: s.bands[75]![d]))
            }
        }
        return out
    }
    var yDomain: ClosedRange<Double> {
        let lo = engines.map { sim[$0].bands[5]!.min()! }.min()!, hi = engines.map { sim[$0].bands[95]!.max()! }.max()!
        return (lo * 0.96)...(hi * 1.04)
    }
    var medians: [Pt] {
        engines.flatMap { e in sim[e].bands[50]!.enumerated().map { Pt(id: "\(e.rawValue)-\($0.offset)", engine: e, day: $0.offset, v: $0.element) } }
    }

    @ChartContentBuilder func bandMark(_ b: Band) -> some ChartContent {
        AreaMark(x: .value("Day", b.day), yStart: .value("Low", b.lo), yEnd: .value("High", b.hi), series: .value("Band", b.group))
            .foregroundStyle(Theme.color(b.engine).opacity(0.22))
            .interpolationMethod(.monotone)
    }
    @ChartContentBuilder func medianMark(_ m: Pt) -> some ChartContent {
        LineMark(x: .value("Day", m.day), y: .value("Median", m.v), series: .value("Median", m.engine.rawValue))
            .foregroundStyle(Theme.color(m.engine))
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
    }

    var body: some View {
        Chart {
            ForEach(bands) { bandMark($0) }
            ForEach(medians) { medianMark($0) }
            RuleMark(y: .value("Today", s0)).foregroundStyle(Theme.real.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Canvas { ctx, _ in
                    guard let plot = proxy.plotFrame else { return }
                    let origin = geo[plot].origin
                    for e in engines {
                        var path = Path()
                        for sample in sim[e].samples {
                            let n = max(2, Int(Double(sample.count) * progress))
                            for (d, v) in sample.prefix(n).enumerated() {
                                guard let x = proxy.position(forX: d), let y = proxy.position(forY: v) else { continue }
                                let p = CGPoint(x: x + origin.x, y: y + origin.y)
                                d == 0 ? path.move(to: p) : path.addLine(to: p)
                            }
                        }
                        ctx.stroke(path, with: .color(Theme.color(e).opacity(0.28)), lineWidth: 0.7)
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis { AxisMarks { AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel() } }
        .chartYAxis { AxisMarks(position: .trailing) { AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel() } }
        .chartLegend(.hidden)
        .frame(height: 260)
    }
}

/// Dónde acaban los 10.000 caminos: histograma del precio final, mismos cortes para los dos motores.
struct TerminalChart: View {
    let sim: Simulation
    let s0: Double
    let filter: Engine?
    var body: some View {
        let edges = sim.histEdges
        Chart {
            ForEach(filter.map { [$0] } ?? Engine.allCases) { e in
                ForEach(Array(sim[e].hist.enumerated()), id: \.offset) { i, c in
                    RectangleMark(xStart: .value("From", edges[i]), xEnd: .value("To", edges[i + 1]), yStart: .value("Zero", 0), yEnd: .value("Paths", c))
                        .foregroundStyle(Theme.color(e).opacity(0.5))
                }
            }
            RuleMark(x: .value("Today", s0)).foregroundStyle(Theme.real.opacity(0.6))
        }
        .chartXScale(domain: edges.first!...edges.last!)
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel() } }
        .frame(height: 140)
    }
}

/// Paso 5: prometido frente a real. Un punto por nivel; la diagonal es la calibración perfecta.
struct CalibrationChart: View {
    let exam: Exam
    var body: some View {
        Chart {
            LineMark(x: .value("Promised", 0), y: .value("Real", 0), series: .value("s", "diag"))
                .foregroundStyle(Theme.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            LineMark(x: .value("Promised", 1), y: .value("Real", 1), series: .value("s", "diag"))
                .foregroundStyle(Theme.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            ForEach(Engine.allCases) { e in
                ForEach(MonteCarlo.levels, id: \.self) { L in
                    LineMark(x: .value("Promised", L), y: .value("Real", exam[e].coverage[L]!), series: .value("s", e.rawValue))
                        .foregroundStyle(Theme.color(e)).lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Promised", L), y: .value("Real", exam[e].coverage[L]!))
                        .foregroundStyle(Theme.color(e)).symbolSize(40)
                }
            }
        }
        .chartXScale(domain: 0...1).chartYScale(domain: 0...1)
        .chartXAxis { AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent()) } }
        .chartYAxis { AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent()) } }
        .chartLegend(.hidden)
        .frame(height: 280)
    }
}

/// Cada fecha del pasado es un punto: dónde cayó el precio real dentro del abanico (0 = por debajo de todo, 1 = por encima).
struct PITStripChart: View {
    let exam: Exam
    let engine: Engine
    var body: some View {
        let pit = exam[engine].pit
        Chart {
            RectangleMark(xStart: .value("a", 0), xEnd: .value("b", pit.count), yStart: .value("lo", 0.05), yEnd: .value("hi", 0.95))
                .foregroundStyle(Theme.color(engine).opacity(0.10))
            RectangleMark(xStart: .value("a", 0), xEnd: .value("b", pit.count), yStart: .value("lo", 0.25), yEnd: .value("hi", 0.75))
                .foregroundStyle(Theme.color(engine).opacity(0.12))
            ForEach(Array(pit.enumerated()), id: \.offset) { i, p in
                PointMark(x: .value("Date", i), y: .value("PIT", p))
                    .foregroundStyle(p < 0.05 || p > 0.95 ? Theme.bad : Theme.color(engine))
                    .symbolSize(p < 0.05 || p > 0.95 ? 28 : 14)
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis { AxisMarks(values: [0.05, 0.5, 0.95]) { AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))) } }
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0, to: pit.count, by: max(1, pit.count / 5)))) { v in
                AxisValueLabel { if let i = v.as(Int.self), i < exam.dates.count { Text(exam.dates[i].prefix(4)) } }
            }
        }
        .frame(height: 120)
    }
}
