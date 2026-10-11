import SwiftUI
import MonteCarloKit

#if canImport(UIKit)
import UIKit
private func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
}
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#else
import AppKit
private func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light) })
}
private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#endif

/// Paleta de la landing aprobada (05/10/2026), con variante clara. Los dos motores tienen color fijo en toda la app.
enum Theme {
    static let bg = dyn(0xF4F6F9, 0x0A0D13)
    static let panel = dyn(0xFFFFFF, 0x10141C)
    static let panel2 = dyn(0xEEF1F6, 0x151A24)
    static let line = dyn(0xDDE2EA, 0x1E2532)
    static let ink = dyn(0x0A0D13, 0xE7EBF1)
    static let muted = dyn(0x5D6779, 0x8D97A8)
    static let gbm = dyn(0x2E6BD6, 0x6FA8FF)
    static let boot = dyn(0xC77A0E, 0xF4AA3E)
    static let good = dyn(0x1F9A5F, 0x4FC48A)
    static let bad = dyn(0xD3473E, 0xF0625A)
    static let real = dyn(0x0A0D13, 0xE7EBF1)

    static func color(_ e: Engine) -> Color { e == .gbm ? gbm : boot }
}

enum Fmt {
    static func pct(_ x: Double, _ d: Int = 1) -> String { num(x * 100, d) + " %" }
    static func num(_ x: Double, _ d: Int = 2) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = d; f.maximumFractionDigits = d
        return f.string(from: x as NSNumber) ?? "\(x)"
    }
    static func money(_ x: Double, _ cur: String) -> String { "\(num(x)) \(cur)" }
    static func int(_ x: Int) -> String { num(Double(x), 0) }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
    }
}

struct Eyebrow: View {
    let step: String, title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted).textCase(.uppercase).kerning(0.6)
            Text(title).font(.title2.weight(.medium)).foregroundStyle(Theme.ink)
        }
    }
}

struct Stat: View {
    let label: String, value: String
    var color: Color = Theme.ink
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Text(value).font(.title.weight(.semibold).monospacedDigit()).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct LegendDot: View {
    let color: Color, text: String
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}
