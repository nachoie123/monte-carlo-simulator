# Monte Carlo Stock Simulator como app nativa (iPhone + Mac): brief

Fecha: 12/10/2026. Decisión de Nacho: vía B (laboratorio con 5 empresas de fábrica + buscador Yahoo
encima), español e inglés, nombre "Monte Carlo Stock Simulator", bundle `com.nachosanbenito.montecarlo`.

## 0. Brief
**Qué es.** Un laboratorio Monte Carlo en el bolsillo: 10.000 futuros de una acción con dos motores (GBM
de libro y bootstrap por bloques de 21 días reales) y un examen que comprueba en ~180 fechas pasadas si
la franja del 90% atrapa de verdad el 90% de las veces. Toda la matemática corre en el aparato
(`apple/MonteCarloKit`, portada de `montecarlo.py` y probada contra sus números).

**Para quién / 3 segundos.** Entrevistadores de quant y reclutadores que abren la app desde el portfolio,
y Nacho enseñándola en una entrevista. En 3 s: el abanico de caminos dibujándose y el marcador
"dijo 90 %, acertó 73 %". Tiene que decir "esto es de verdad y es difícil" sin leer nada.

**Tipo.** Finanzas: fórmula real en pantalla, números reales (μ, σ, VaR, ES, cobertura), método y su
límite medido (paso 6). Simple de leer: un titular llano por paso, el mecanismo debajo.

**Qué hay ya.** Los 6 pasos y textos de la web `docs/demo/index.html` (se traducen al inglés, no se
reescriben); la paleta de la landing aprobada el 05/10 (`#0A0D13` fondo, `#6FA8FF` GBM, `#F4AA3E`
bootstrap, `#4FC48A` cumple, `#F0625A` falla, texto `#E7EBF1`, apagado `#8D97A8`); los precios de
5 empresas (Apple, Inditex, Nvidia, Repsol, SPY) dentro del paquete; el vídeo y el dosier de la web.

**Qué falla hoy (la web en un iPhone).** Es una página de scroll largo pensada para 1280 px: la fórmula se
corta, el cono se vuelve ilegible a 390 px y no hay forma de jugar con los parámetros (solo 3 horizontes).
Una app nativa gana lo que la web no tiene: mandos (horizonte, bloque, semilla, caminos) que recalculan
al instante, tipografía dinámica, modo claro y oscuro del sistema y funcionar sin red.

## 1. Referencia
La misma de la landing: **seeing-theory.brown.edu** (ADN en
`~/Projects/nachosanbenito-web/docs/landings-rediseno/monte-carlo-simulator/adn.json`). Se toma: el
gráfico enseña y el texto acompaña; puntos que caen y se acumulan en histogramas; pares "observado vs
teórico" en dos colores fijos; ejes finos con etiquetas pequeñas; títulos sin negrita. No se toma: píldoras,
fondo amarillo, tipografía Assistant (en nativo, San Francisco con cifras en monoespaciada).

Traducción a nativo: panel de texto teñido + escenario = en iPhone, cada paso es una tarjeta con el gráfico
arriba y el texto debajo; en Mac, `NavigationSplitView` con la lista de empresas a la izquierda y los pasos
a la derecha, el gráfico ocupando el ancho.

## 2. Concepto: el objeto
**El abanico que se dibuja y pasa el examen.** Al elegir una empresa, 40 caminos de muestra se dibujan
uno a uno (0,6 s, ease-out), las franjas del 50 % y 90 % se rellenan detrás, y los 10.000 finales caen en
el histograma de la derecha. Al bajar, el mismo abanico se convierte en examen: cada fecha del pasado es un
punto que se enciende dentro o fuera de la franja. Los mandos del laboratorio (horizonte, bloque, semilla)
redibujan el abanico; eso es lo que la web no puede hacer.

Descartadas: tablero de Galton (inventa una mecánica que el modelo no usa) y marcador del hombre del
tiempo solo (se integra como paso 5).

## 3. Recursos reales
- `MonteCarloKit` con 5 series de precios y tests de paridad con el Python (15 fixtures).
- Textos de los 6 pasos: `docs/demo/index.html` (español) → `Localizable.xcstrings` con inglés.
- Icono: abanico de líneas azul/naranja sobre `#0A0D13`, dibujado en SVG propio.
- Tramo 2: buscador Yahoo (`query2.finance.yahoo.com/v1/finance/search` + `v8/finance/chart`), sin clave.

## 4. Direcciones
Nacho fijó referencia y concepto en el chat (12/10/2026); se construye directo y se revisa con capturas del
simulador de iPhone y del Mac al lado de la landing.
