# Revisión de diseño 1 (webdesign 4.3, revisor opus) · 12/10/2026 09:50

Comparaciones en `docs/nativa/revision-1/` (izquierda landing, derecha app): A portada/Mac, B receta, C cono, D examen,
E límites, F móvil (iPhone oscuro/claro), `bigtype.jpg` = letra grande OK. Capturas del Mac con `docs/nativa/mac_shots.py`
(hace clic en la ventana para darle foco: sin ese clic los eventos de rueda no mueven el scroll; captura por id de ventana).
Aviso: en B y C la landing salía con "Chart data could not load" (file://, el demo lee JSON): revisadas contra el código.

## Puntuaciones (objetivo ≥ 8 en todas, mínimo 2 vueltas)
jerarquía 5 · tipografía 6 · color 5 · espacio 7 · hecho a mano 6 · legibilidad gráficas 5 · enseña finanzas 6

## Arreglos por impacto (archivo:línea de la versión de 09:17)
**Los dos**
1. Abanico + histograma de lado como PORTADA dentro de `verdict(a)` (`ChartViews.swift:72-103`, `StoryView.swift:115-131`):
   HStack con ConeChart + histograma final girado (RectangleMark yStart/yEnd), misma `chartYScale`, 90 pt ancho Mac / 64 iPhone,
   alto 300/220. Paso 3 queda como versión detallada.
2. Veredicto como frase grande en vez de 4 tarjetas iguales (`StoryView.swift:119-123`): por motor "GBM dijo 90 %, acertó" `.title3`
   + cifra `.system(size: 44, weight: .light).monospacedDigit()` en el color del motor + cuadrado 8 pt good/bad/boot con la palabra.
   El 50 % en Grid 2×2 pequeño debajo.
3. Cono legible con los dos motores (`ChartViews.swift:61-70, :93`): franja 90 % = dos LineMark (p5, p95) 1 pt sin relleno; franja
   50 % relleno 0,16; caminos opacidad 0,14 y grosor 0,5, 20 por motor con "Los dos"; `ctx.clip(to: Path(geo[plot]))` (línea 82);
   `.chartXScale(domain: 0...days)`; `.chartXAxisLabel("días de bolsa")`.
4. Histograma final (`ChartViews.swift:114-118`): GBM contorno LineMark `.stepCenter` 1,5 pt azul; bootstrap relleno naranja 0,45.
5. Margen de suerte DIBUJADO en la calibración (`ChartViews.swift:133-146`): AreaMark por nivel L entre L±1,96·√(L(1−L)/n) en
   `Theme.muted.opacity(0.12)`; ejes con `.chartXAxisLabel(t.calibX)` / `.chartYAxisLabel(t.calibY)` (quitar HStack `StoryView.swift:242`).
6. Paso 1 colores con significado (`ChartViews.swift:13, :17`, leyenda `StoryView.swift:140`): días reales en `Theme.boot.opacity(0.6)`,
   curva normal en `Theme.gbm` 2 pt, >4σ en bad; tarjetas "28" naranja y "0,32" azul.
7. Números en el idioma de la app (`Theme.swift:45-50`): `f.locale` es_ES/en_US según `Bundle.main.preferredLocalizations`;
   `%` pegado en inglés; `f.minusSign = "−"`; `.environment(\.locale, …)` en el ScrollView (`StoryView.swift:11`); fecha del
   dek con `Date.FormatStyle().day().month(.abbreviated).year()` (`Copy.swift:39/82`).
8. Fórmulas (`StoryView.swift:163-176`, `Copy.swift:47/90`): solo S, T, μ, σ, Z en cursiva; `exp`, `N`, `=` en serif recto.
   Segunda fórmula del bootstrap en naranja: `S_{t+1} = S_t · exp(r_{i+k}),  i ~ U{1 … 1.260 − b}`. Filete 2 pt a la izquierda
   en el color del motor. Pie: "día a día, Δt = 1/252".
**iPhone**
9. Primera pantalla (`StoryView.swift:13-24`): header → verdict (con el abanico) → controls → pasos; mientras calcula, gráfico vacío
   con ejes en vez de "Simulating…"; `t.lead` a `.lineLimit(3)` en iPhone.
**Mac**
10. Alturas con `#if os(macOS)`: colas 240, cono 340, calibración 320 (`ChartViews.swift:26, 102, 151`). Veredicto con
    `GridItem(.flexible())` fijas. Tabla paso 4: cifras `.frame(minWidth: 110, alignment: .trailing)`, etiqueta `maxWidth: 360`.
11. Barra lateral (`MonteCarloApp.swift:50`, `Copy.swift:71/114`): ticker en `.caption` normal (NO monoespaciada; también
    `StoryView.swift:53`); placeholder "Buscar empresa o ticker" / "Search company or ticker"; `addHint` como `.help(...)` en Mac.
12. Entradillas (`Theme.swift:67`, `StoryView.swift:49, 68`): quitar `.textCase(.uppercase).kerning(0.6)`; `.subheadline` en muted.
13. Tira del examen (`ChartViews.swift:175`): valores hasta `pit.count - pit.count/8` para que no se corte el último año.
14. Bajo cada tira (`StoryView.swift:248-251`): "fuera de la franja: 14 de 177 (7,9 %), se esperaban 10 %" (texto en Copy.swift).

Fila naranja de la barra lateral del Mac: DEJARLA (acento del sistema de Nacho; los demás la verán azul).

## No tocar
Paleta claro/oscuro; cifras monoespaciadas y controles nativos del laboratorio; paso 1 en log con colas rojas; tira del examen con
fallos en rojo; textos de pasos 4–6 y "Ojo con la muestra"; atenuado 0,55 al recalcular; margen ±1,96·√(0,09/n).

## Contenido de finanzas (revisor)
- Cuentas OK: μ = media·252 + σ²/2 en Kit y Python; Apple 336,64·e^((0,216−0,039)·0,25) ≈ 351,9 vs mediana app 351,20.
- Falta fórmula del bootstrap (arreglo 8) y aclarar que la simulación va día a día.
- Margen de suerte: el ±7,7 es para el 90 %; para el 50 % sería √(0,25/n) ≈ ±12,8 con n=59 y no se dice.
- Signos: VaR/ES en positivo y peor día en negativo; elegir convención (cabecera "pérdida").
- Lo más quant de la landing (16 acciones, Kupiec + KS) no está en la app ni en MonteCarloKit. Mínimo: p-valor de Kupiec
  en el veredicto (binomial de aciertos frente al 90 % con n efectivo). Decidir con Nacho si entra (coste: Kit + tests).
