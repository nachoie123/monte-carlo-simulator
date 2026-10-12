import Foundation
import MonteCarloKit

/// Todos los textos de la app en español e inglés. Los del español son los de la web (`docs/demo/index.html`).
/// ponytail: un struct por idioma en vez de un catálogo .xcstrings; añadir un idioma = otro struct.
struct Copy {
    static let current: Copy = Bundle.main.preferredLocalizations.first == "es" ? .es : .en   // sigue el idioma del sistema o el de la app en Ajustes

    let appTitle: String, kicker: String, lead: String
    let horizon: [Horizon: String]
    let lab: String, horizonLabel: String, blockLabel: String, pathsLabel: String, reseed: String, seedLabel: String
    let both: String, gbm: String, bootstrap: String
    let companies: String, closeOf: String, resolved: (String) -> String
    let dek: (Analysis) -> String
    let verdictTitle: (String) -> String, said: (Engine, Int) -> String
    let fulfils: String, overconfident: String, exaggerates: String
    let verdictSentence: (String, String, Double, Double) -> String
    let step1: String, step1Title: String, realDays: String, bellWould: String
    let tailStats: (Tails) -> [(String, String)]
    let step2: String, step2Title: String, step2Text: String, formulaCaption: (Analysis, Int) -> String
    let step3: String, step3Title: String, legend90: (Engine) -> String, today: String, whereTheyEnd: String
    let step4: String, step4Title: String, step4Text: String
    let rows: (EngineSummary, EngineSummary, String) -> [(String, String, String, String)]
    let step5: String, step5Title: String, step5Text: (Int) -> String, calibTitle: String
    let calibX: String, calibY: String, perfect: String, stripTitle: String
    let caveat: (Exam, String) -> String
    let step6: String, step6Title: String, limits: [(String, String)]
    let footer: (Analysis) -> String, notAdvice: String, author: String
    let computing: String
    let addPrompt: String, addHint: String, notFound: (String) -> String, remove: String

    static let es = Copy(
        appTitle: "Monte Carlo Stock Simulator", kicker: "Simulador que se examina",
        lead: "10.000 futuros para una acción. Y un examen para el que los dibuja. Un simulador Monte Carlo no adivina el precio de mañana: dibuja todos los caminos posibles y dice «el 90 % de las veces, el precio caerá aquí». Este, además, se pone a prueba contra 15 años de fechas reales para ver si esa promesa se cumple.",
        horizon: [.oneMonth: "1 mes", .threeMonths: "3 meses", .oneYear: "1 año"],
        lab: "Laboratorio", horizonLabel: "Horizonte", blockLabel: "Bloque del bootstrap", pathsLabel: "Caminos", reseed: "Otra semilla", seedLabel: "Semilla",
        both: "Los dos", gbm: "GBM", bootstrap: "Bootstrap",
        companies: "Empresas", closeOf: "cierre del", resolved: { "cotización \($0)" },
        dek: { a in "10.000 caminos simulados con dos motores desde \(Fmt.money(a.s0, a.currency)) (cierre del \(a.lastDate)). Después, el examen: \(Fmt.int(a.exam.origins)) fechas reales desde \(a.exam.dates.first?.prefix(4) ?? "") para ver si la franja del 90 % atrapa de verdad el 90 % de las veces." },
        verdictTitle: { "El veredicto a \($0)" }, said: { e, L in "\(e == .gbm ? "GBM" : "Bootstrap"): dijo \(L) %, acertó" },
        fulfils: "cumple", overconfident: "se confía demasiado", exaggerates: "exagera el riesgo",
        verdictSentence: { g, b, ind, moe in "Franja del 90 %: el GBM \(g) y el bootstrap \(b). Con \(Fmt.num(ind, 0)) pruebas independientes, la suerte sola mueve el resultado ±\(Fmt.num(moe * 100, 1)) puntos, y solo cuenta como fallo lo que se sale de ese margen. Por encima de la diagonal, el simulador pinta un futuro más incierto de lo que fue. Por debajo, se lleva sorpresas." },
        step1: "Paso 1 · Los datos", step1Title: "La bolsa no es una campana", realDays: "Días reales", bellWould: "Lo que diría la campana",
        tailStats: { t in [("Días de ±4σ reales", "\(t.crashDaysReal)"), ("Los que prevé la campana", Fmt.num(t.crashDaysNormal, 2)), ("Curtosis extra", Fmt.num(t.excessKurtosis, 1)), ("Peor día", Fmt.pct(t.worstDay))] },
        step2: "Paso 2 · La receta", step2Title: "Dos maneras de inventar el futuro",
        step2Text: "El primer motor, GBM, es la fórmula de libro: el mismo modelo que hay debajo de Black–Scholes. Cada día sale de una campana con la media y la volatilidad de los últimos 5 años. El segundo, bootstrap, no inventa nada: copia y pega bloques enteros de días reales del pasado en orden aleatorio, para que los crashes vuelvan a salir y lo hagan en racimo.",
        formulaCaption: { a, b in "Calibrado con los últimos 1.260 días (5 años): μ = \(Fmt.pct(a.muAnnual)) anual, σ = \(Fmt.pct(a.sigmaAnnual)) anual. Bootstrap: bloques de \(b) días." },
        step3: "Paso 3 · El cono", step3Title: "10.000 caminos posibles", legend90: { "\($0 == .gbm ? "GBM" : "Bootstrap"): franja del 90 % y del 50 %" }, today: "Precio de hoy", whereTheyEnd: "Dónde acaban los 10.000 caminos",
        step4: "Paso 4 · Las cifras", step4Title: "Lo que un gestor de riesgos preguntaría",
        step4Text: "Las mismas cinco preguntas con los dos motores. Si dan cosas parecidas, el resultado no depende de suponer una campana. Si no, la diferencia es justo el riesgo que la campana no ve.",
        rows: { g, b, cur in [
            ("Precio mediano al final", "la mitad de los caminos acaban por encima", Fmt.money(g.median, cur), Fmt.money(b.median, cur)),
            ("Probabilidad de ganar", "caminos que acaban por encima de hoy", Fmt.pct(g.pUp), Fmt.pct(b.pUp)),
            ("VaR 95 %", "pérdida que solo se supera 1 de cada 20 veces", Fmt.pct(g.var95), Fmt.pct(b.var95)),
            ("ES 95 %", "pérdida media cuando se supera el VaR", Fmt.pct(g.es95), Fmt.pct(b.es95)),
            ("Caída máxima típica", "mediana del peor bajón dentro del camino", Fmt.pct(g.maxDDMedian), Fmt.pct(b.maxDDMedian))] },
        step5: "Paso 5 · El examen", step5Title: "¿Cumple lo que promete?",
        step5Text: { n in "Como al hombre del tiempo: no se le juzga por un día, sino por si llueve el 70 % de las veces que dice «70 %». Coloco el simulador en \(Fmt.int(n)) fechas del pasado, lo calibro con los 5 años anteriores a cada una y miro en qué punto de su abanico cayó el precio real." },
        calibTitle: "Prometido frente a real", calibX: "lo que el simulador promete (franja central)", calibY: "veces que el precio real cayó dentro", perfect: "Calibración perfecta",
        stripTitle: "Cada punto es una fecha del pasado. Fuera de la franja = el precio real se salió de lo previsto",
        caveat: { ex, h in "Ojo con la muestra. Las \(ex.origins) fechas están separadas por un mes, pero cada prueba mira \(h) hacia delante, así que se pisan entre sí. Equivalen a unas \(Fmt.num(ex.independent, 0)) pruebas independientes. " + (ex.independent >= 150 ? "Es una muestra sólida: la suerte solo explica unos ±4 puntos en la franja del 90 % y ±7 en la del 50 %." : ex.independent < 40 ? "Es poco para un veredicto firme: mira el horizonte de 1 mes, donde la prueba es sólida." : "Para el veredicto más firme, compáralo con el horizonte de 1 mes (~180 pruebas independientes).") },
        step6: "Paso 6 · Lo que este modelo NO hace", step6Title: "Dónde termina la herramienta",
        limits: [
            ("No predice la dirección", "La deriva μ sale de la media de los últimos 5 años, y es casi todo ruido: unos años buenos inflan cualquier proyección. Lo útil del cono es su anchura, no hacia dónde apunta."),
            ("Volatilidad constante", "Los dos motores suponen que el riesgo de los próximos meses se parece al de los últimos 5 años. Tras un crash no es así. Modelar eso es GARCH (Quantum #5)."),
            ("El examen tiene poca muestra a 1 año", "Las fechas de examen cubren ~15 años (de los 20 de datos, los 5 primeros solo calibran): a 1 año son unos 14 tramos que no se pisan entre sí. A 1 mes hay ~180 pruebas independientes: ese veredicto es el sólido."),
            ("Sesgo de superviviente", "Solo se pueden simular empresas que siguen cotizando hoy. Las que quebraron no entran en el examen.")],
        footer: { a in "Datos: Yahoo Finance (precios ajustados por dividendos y splits), histórico desde \(a.historyFrom). \(Fmt.int(a.nPaths)) caminos por motor, semilla fija. La matemática corre en este aparato (MonteCarloKit, portado de montecarlo.py y probado contra sus números)." },
        notAdvice: "No es asesoramiento financiero.", author: "Ignacio San Benito · IE University",
        computing: "Simulando 10.000 futuros y examinando 15 años…",
        addPrompt: "Añadir empresa: nombre o ticker", addHint: "Cualquier acción o ETF, con datos de Yahoo Finance (sin cuenta). Las cinco primeras vienen dentro de la app por si Yahoo falla.",
        notFound: { "No encontré una acción con histórico suficiente (6,5 años) y datos limpios para «\($0)». Prueba con el ticker exacto (p. ej. ITX.MC)." },
        remove: "Quitar")

    static let en = Copy(
        appTitle: "Monte Carlo Stock Simulator", kicker: "A simulator that grades itself",
        lead: "10,000 futures for one stock. And an exam for whoever draws them. A Monte Carlo simulator does not guess tomorrow's price: it draws every possible path and says “90% of the time, the price will land here”. This one also sits the exam against 15 years of real dates to see whether that promise holds.",
        horizon: [.oneMonth: "1 month", .threeMonths: "3 months", .oneYear: "1 year"],
        lab: "Lab", horizonLabel: "Horizon", blockLabel: "Bootstrap block", pathsLabel: "Paths", reseed: "New seed", seedLabel: "Seed",
        both: "Both", gbm: "GBM", bootstrap: "Bootstrap",
        companies: "Companies", closeOf: "close of", resolved: { "ticker \($0)" },
        dek: { a in "10,000 paths simulated with two engines from \(Fmt.money(a.s0, a.currency)) (close of \(a.lastDate)). Then the exam: \(Fmt.int(a.exam.origins)) real dates since \(a.exam.dates.first?.prefix(4) ?? "") to see whether the 90% band really catches the price 90% of the time." },
        verdictTitle: { "The verdict at \($0)" }, said: { e, L in "\(e == .gbm ? "GBM" : "Bootstrap"): promised \(L)%, got" },
        fulfils: "keeps its promise", overconfident: "is overconfident", exaggerates: "overstates the risk",
        verdictSentence: { g, b, ind, moe in "90% band: GBM \(g) and bootstrap \(b). With \(Fmt.num(ind, 0)) independent trials, luck alone moves the result by ±\(Fmt.num(moe * 100, 1)) points, so only what falls outside that margin counts as a miss. Above the diagonal, the simulator paints a more uncertain future than the one that happened. Below it, it gets surprised." },
        step1: "Step 1 · The data", step1Title: "The market is not a bell curve", realDays: "Real days", bellWould: "What the bell curve would say",
        tailStats: { t in [("Real ±4σ days", "\(t.crashDaysReal)"), ("Days the bell curve expects", Fmt.num(t.crashDaysNormal, 2)), ("Excess kurtosis", Fmt.num(t.excessKurtosis, 1)), ("Worst day", Fmt.pct(t.worstDay))] },
        step2: "Step 2 · The recipe", step2Title: "Two ways to invent the future",
        step2Text: "The first engine, GBM, is the textbook formula: the same model underneath Black–Scholes. Each day is drawn from a bell curve with the mean and volatility of the last 5 years. The second, bootstrap, invents nothing: it copies and pastes whole blocks of real past days in random order, so crashes can happen again, and in clusters.",
        formulaCaption: { a, b in "Calibrated on the last 1,260 trading days (5 years): μ = \(Fmt.pct(a.muAnnual)) a year, σ = \(Fmt.pct(a.sigmaAnnual)) a year. Bootstrap: blocks of \(b) days." },
        step3: "Step 3 · The cone", step3Title: "10,000 possible paths", legend90: { "\($0 == .gbm ? "GBM" : "Bootstrap"): 90% and 50% bands" }, today: "Today's price", whereTheyEnd: "Where the 10,000 paths end",
        step4: "Step 4 · The numbers", step4Title: "What a risk manager would ask",
        step4Text: "The same five questions with both engines. If they agree, the answer does not depend on assuming a bell curve. If they don't, the gap is exactly the risk the bell curve cannot see.",
        rows: { g, b, cur in [
            ("Median final price", "half the paths end above it", Fmt.money(g.median, cur), Fmt.money(b.median, cur)),
            ("Probability of a gain", "paths ending above today's price", Fmt.pct(g.pUp), Fmt.pct(b.pUp)),
            ("VaR 95%", "the loss exceeded only 1 time in 20", Fmt.pct(g.var95), Fmt.pct(b.var95)),
            ("ES 95%", "average loss when VaR is exceeded", Fmt.pct(g.es95), Fmt.pct(b.es95)),
            ("Typical max drawdown", "median of the worst dip along the path", Fmt.pct(g.maxDDMedian), Fmt.pct(b.maxDDMedian))] },
        step5: "Step 5 · The exam", step5Title: "Does it keep its promise?",
        step5Text: { n in "Like a weather forecaster: you don't judge one day, you check whether it rains 70% of the times they say “70%”. I place the simulator at \(Fmt.int(n)) past dates, calibrate it on the 5 years before each one and look at where in its fan the real price landed." },
        calibTitle: "Promised versus real", calibX: "what the simulator promises (central band)", calibY: "times the real price fell inside", perfect: "Perfect calibration",
        stripTitle: "Each dot is a past date. Outside the band = the real price escaped the forecast",
        caveat: { ex, h in "Mind the sample. The \(ex.origins) dates are a month apart, but each trial looks \(h) ahead, so they overlap. They amount to about \(Fmt.num(ex.independent, 0)) independent trials. " + (ex.independent >= 150 ? "That is a solid sample: luck alone explains about ±4 points in the 90% band and ±7 in the 50% band." : ex.independent < 40 ? "Too few for a firm verdict: check the 1-month horizon, where the test is solid." : "For the firmest verdict, compare with the 1-month horizon (~180 independent trials).") },
        step6: "Step 6 · What this model does NOT do", step6Title: "Where the tool ends",
        limits: [
            ("It does not predict direction", "The drift μ comes from the average of the last 5 years, and that is mostly noise: a few good years inflate any projection. The useful part of the cone is its width, not where it points."),
            ("Constant volatility", "Both engines assume the risk of the coming months looks like the last 5 years. After a crash it doesn't. Modelling that is GARCH (Quantum #5)."),
            ("The exam is thin at 1 year", "Exam dates span ~15 years (of 20 years of data, the first 5 only calibrate): at 1 year that is about 14 non-overlapping stretches. At 1 month there are ~180 independent trials: that verdict is the solid one."),
            ("Survivorship bias", "Only companies still trading today can be simulated. The ones that went bust never sit the exam.")],
        footer: { a in "Data: Yahoo Finance (prices adjusted for dividends and splits), history since \(a.historyFrom). \(Fmt.int(a.nPaths)) paths per engine, fixed seed. All the maths runs on this device (MonteCarloKit, ported from montecarlo.py and tested against its numbers)." },
        notAdvice: "Not financial advice.", author: "Ignacio San Benito · IE University",
        computing: "Simulating 10,000 futures and grading 15 years…",
        addPrompt: "Add a company: name or ticker", addHint: "Any stock or ETF, with data from Yahoo Finance (no account). The first five ship inside the app in case Yahoo is down.",
        notFound: { "No stock with enough history (6.5 years) and clean data found for “\($0)”. Try the exact ticker (e.g. ITX.MC)." },
        remove: "Remove")
}
