import SwiftUI
import MonteCarloKit

/// Los 6 pasos de la web, en orden, para una empresa. El gráfico enseña, el texto acompaña.
struct StoryView: View {
    @Bindable var lab: Lab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let t = Copy.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                controls
                if let a = lab.analysis {
                    Group {
                        verdict(a)
                        step1(a)
                        step2(a)
                        step3(a)
                        step4(a)
                        step5(a)
                        step6
                        footer(a)
                    }
                    .opacity(lab.running ? 0.55 : 1)
                    .animation(.easeOut(duration: 0.25), value: lab.running)
                } else if let e = lab.error {
                    Card { Text(e).foregroundStyle(Theme.bad) }
                } else {
                    Card { HStack { ProgressView(); Text(t.computing).foregroundStyle(Theme.muted) } }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .navigationTitle(lab.selected?.name ?? t.appTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: cabecera y mandos

    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.kicker).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted).textCase(.uppercase).kerning(0.6)
            if let s = lab.selected {
                HStack(alignment: .firstTextBaseline) {
                    Text(s.name).font(.largeTitle.weight(.medium)).foregroundStyle(Theme.ink)
                    Text(s.symbol).font(.callout.monospaced()).foregroundStyle(Theme.muted)
                }
            }
            if let a = lab.analysis {
                Text(t.dek(a)).font(.body).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(t.lead).font(.body).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var controls: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(t.lab).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted).textCase(.uppercase).kerning(0.6)
                    Spacer()
                    if lab.running { ProgressView().controlSize(.small) }
                }
                Picker(t.horizonLabel, selection: $lab.horizon) {
                    ForEach(Horizon.allCases) { Text(t.horizon[$0]!).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { blockPicker; pathsPicker; Spacer(); seedButton }
                    VStack(alignment: .leading, spacing: 10) { blockPicker; pathsPicker; seedButton }
                }
            }
        }
    }

    var blockPicker: some View {
        HStack(spacing: 8) {
            Text(t.blockLabel).font(.subheadline).foregroundStyle(Theme.muted)
            Picker(t.blockLabel, selection: $lab.block) { ForEach(Lab.blocks, id: \.self) { Text("\($0)").tag($0) } }
                .pickerStyle(.menu).labelsHidden().fixedSize()
        }
    }
    var pathsPicker: some View {
        HStack(spacing: 8) {
            Text(t.pathsLabel).font(.subheadline).foregroundStyle(Theme.muted)
            Picker(t.pathsLabel, selection: $lab.nPaths) { ForEach(Lab.pathCounts, id: \.self) { Text(Fmt.int($0)).tag($0) } }
                .pickerStyle(.menu).labelsHidden().fixedSize()
        }
    }
    var seedButton: some View {
        Button { lab.reseed() } label: {
            Label("\(t.reseed) · \(lab.seed)", systemImage: "shuffle").font(.subheadline).monospacedDigit()
        }.buttonStyle(.bordered).tint(Theme.ink)
    }

    // MARK: veredicto

    struct Tile: Identifiable { let e: Engine; let L: Int; var id: String { "\(e.rawValue)\(L)" }
        static let all = [Tile(e: .gbm, L: 90), Tile(e: .bootstrap, L: 90), Tile(e: .gbm, L: 50), Tile(e: .bootstrap, L: 50)] }

    func verdictWord(_ a: Analysis, _ e: Engine) -> (String, Color) {
        let ex = a.exam
        let moe = 1.96 * (0.9 * 0.1 / ex.independent).squareRoot()
        let d = ex[e].coverage[0.9]! - 0.9
        return abs(d) <= moe ? (t.fulfils, Theme.good) : d < 0 ? (t.overconfident, Theme.bad) : (t.exaggerates, Theme.boot)
    }

    func verdict(_ a: Analysis) -> some View {
        let ex = a.exam
        return VStack(alignment: .leading, spacing: 10) {
            Text(t.verdictTitle(t.horizon[a.horizon]!)).font(.title2.weight(.medium)).foregroundStyle(Theme.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(Tile.all) { tile in
                    Stat(label: t.said(tile.e, tile.L), value: Fmt.pct(ex[tile.e].coverage[Double(tile.L) / 100]!), color: Theme.color(tile.e))
                }
            }
            .id("\(a.symbol)\(a.horizon)")   // la ForEach id cambia con el motor, no con la cifra
            HStack(spacing: 4) {
                let g = verdictWord(a, .gbm), b = verdictWord(a, .bootstrap)
                Text(t.verdictSentence(g.0, b.0, ex.independent, 1.96 * (0.9 * 0.1 / ex.independent).squareRoot()))
                    .font(.callout).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: pasos

    func step1(_ a: Analysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(step: t.step1, title: t.step1Title)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) { LegendDot(color: Theme.gbm.opacity(0.7), text: t.realDays); LegendDot(color: Theme.ink, text: t.bellWould); LegendDot(color: Theme.bad, text: "> 4σ") }
                    TailsChart(tails: a.tails)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                        ForEach(t.tailStats(a.tails), id: \.0) { Stat(label: $0.0, value: $0.1) }
                    }
                }
            }
        }
    }

    func step2(_ a: Analysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(step: t.step2, title: t.step2Title)
            Text(t.step2Text).font(.body).foregroundStyle(Theme.ink.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    formula
                    Text(t.formulaCaption(a, lab.block)).font(.footnote).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// S_T = S₀ · exp((μ − σ²/2)·T + σ·√T·Z),  Z ~ N(0, 1)
    var formula: some View {
        ViewThatFits(in: .horizontal) {
            formulaText(size: 22)
            formulaText(size: 17)
        }
    }
    func formulaText(size: CGFloat) -> Text {
        let f = Font.system(size: size, design: .serif).italic()
        let small = Font.system(size: size * 0.65, design: .serif)
        return Text("S").font(f) + Text("T").font(small).baselineOffset(-size * 0.3)
            + Text(" = S").font(f) + Text("0").font(small).baselineOffset(-size * 0.3)
            + Text(" · exp((μ − σ²/2)·T + σ·√T·Z),   Z ~ N(0, 1)").font(f)
    }

    @State private var coneStart = Date()
    func step3(_ a: Analysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(step: t.step3, title: t.step3Title)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $lab.engineFilter) {
                        Text(t.both).tag(Engine?.none); Text(t.gbm).tag(Engine?.some(.gbm)); Text(t.bootstrap).tag(Engine?.some(.bootstrap))
                    }.pickerStyle(.segmented).frame(maxWidth: 360)
                    TimelineView(.animation(paused: reduceMotion || Date().timeIntervalSince(coneStart) > 1.2)) { ctx in
                        let p = reduceMotion ? 1 : min(1, ctx.date.timeIntervalSince(coneStart) / 0.9)
                        ConeChart(sim: a.sim, s0: a.s0, filter: lab.engineFilter, progress: 1 - pow(1 - p, 3))
                    }
                    .onChange(of: a.sim) { coneStart = Date() }
                    HStack(spacing: 14) {
                        ForEach(Engine.allCases) { LegendDot(color: Theme.color($0), text: t.legend90($0)) }
                        LegendDot(color: Theme.real.opacity(0.6), text: t.today)
                    }.font(.caption)
                    Text(t.whereTheyEnd).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink).padding(.top, 6)
                    TerminalChart(sim: a.sim, s0: a.s0, filter: lab.engineFilter)
                }
            }
        }
    }

    func step4(_ a: Analysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(step: t.step4, title: t.step4Title)
            Text(t.step4Text).font(.body).foregroundStyle(Theme.ink.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            Card {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text(t.horizon[a.horizon]!).font(.footnote).foregroundStyle(Theme.muted)
                        Text(t.gbm).font(.footnote.weight(.semibold)).foregroundStyle(Theme.gbm).gridColumnAlignment(.trailing)
                        Text(t.bootstrap).font(.footnote.weight(.semibold)).foregroundStyle(Theme.boot).gridColumnAlignment(.trailing)
                    }
                    Divider()
                    ForEach(t.rows(a.sim[.gbm], a.sim[.bootstrap], a.currency), id: \.0) { r in
                        GridRow(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.0).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                                Text(r.1).font(.caption).foregroundStyle(Theme.muted)
                            }.fixedSize(horizontal: false, vertical: true)
                            Text(r.2).font(.body.monospacedDigit()).foregroundStyle(Theme.gbm)
                            Text(r.3).font(.body.monospacedDigit()).foregroundStyle(Theme.boot)
                        }
                    }
                }
            }
        }
    }

    func step5(_ a: Analysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(step: t.step5, title: t.step5Title)
            Text(t.step5Text(a.exam.origins)).font(.body).foregroundStyle(Theme.ink.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t.calibTitle).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                    HStack(spacing: 14) {
                        ForEach(Engine.allCases) { LegendDot(color: Theme.color($0), text: $0 == .gbm ? t.gbm : t.bootstrap) }
                        LegendDot(color: Theme.muted, text: t.perfect)
                    }
                    CalibrationChart(exam: a.exam)
                    HStack { Text(t.calibX); Spacer(); Text("↑ " + t.calibY) }.font(.caption2).foregroundStyle(Theme.muted)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t.stripTitle).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    ForEach(Engine.allCases) { e in
                        LegendDot(color: Theme.color(e), text: e == .gbm ? t.gbm : t.bootstrap)
                        PITStripChart(exam: a.exam, engine: e)
                    }
                }
            }
            Text(t.caveat(a.exam, t.horizon[a.horizon]!)).font(.callout).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                .padding(14).background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    var step6: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(step: t.step6, title: t.step6Title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                ForEach(t.limits, id: \.0) { l in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l.0).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text(l.1).font(.footnote).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    func footer(_ a: Analysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.footer(a)).font(.footnote).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Text(t.notAdvice).font(.footnote).foregroundStyle(Theme.muted)
            Text(t.author).font(.footnote.weight(.medium)).foregroundStyle(Theme.ink).padding(.top, 8)
        }.padding(.vertical, 12)
    }
}
