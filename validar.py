"""Validación del modelo (necesita red, ~2 min): ¿sus promesas se cumplen en 16 acciones?
A 1 mes, por motor: cobertura de las franjas del 50% y del 90%, test de Kupiec sobre las roturas
del VaR 95% (el que usa Basilea para aprobar un modelo de riesgo; p < 0,05 = suspende) y test de
Kolmogorov-Smirnov sobre los PIT (un modelo calibrado los deja repartidos de forma uniforme entre 0 y 1).
Uso: python3 validar.py
"""
import math
import numpy as np
from scipy import stats

import montecarlo as mc

# 3) ¿Es bueno? examen en 16 acciones, 1 mes, con pruebas formales
TICK = ["SPY","QQQ","AAPL","MSFT","JPM","XOM","KO","PG","JNJ","WMT","NVDA","AMZN","SAN.MC","ITX.MC","IBE.MC","BP.L"]
print("3) examen a 1 mes (cobertura 50/90, Kupiec VaR95, KS uniformidad PIT)")
print(f"   {'':8}{'gbm50':>7}{'boot50':>7}{'gbm90':>7}{'boot90':>7}  {'Kupiec p gbm/boot':>18}  {'KS p gbm/boot':>15}")
agg = {"gbm": [], "bootstrap": []}
for q in TICK:
    try: c, _, _ = mc.load(q)
    except Exception as e: print("   ", q, "sin datos:", e); continue
    ex = mc.exam(np.diff(np.log(c.to_numpy())), 21)
    row = []
    for e in mc.ENGINES:
        p = np.array(ex[e]["pit"]); agg[e] += list(p)
        n, x = len(p), int((p < .05).sum())          # roturas del VaR 95% (precio por debajo del 5%)
        ph = x/n
        lr = -2*((n-x)*math.log(.95)+x*math.log(.05)) + 2*((n-x)*math.log(1-ph)+(x*math.log(ph) if x else 0))
        row.append((ex[e]["coverage"]["0.5"], ex[e]["coverage"]["0.9"], stats.chi2.sf(lr,1), stats.kstest(p,"uniform").pvalue))
    g, b = row
    print(f"   {q:8}{g[0]*100:7.0f}{b[0]*100:7.0f}{g[1]*100:7.0f}{b[1]*100:7.0f}  {g[2]:8.2f} / {b[2]:<8.2f} {g[3]:6.3f} / {b[3]:<6.3f}")
for e in mc.ENGINES:
    p = np.array(agg[e])
    print(f"   TOTAL {e:10} n={len(p)}  cobertura50 {np.mean(abs(p-.5)<=.25)*100:.1f}%  cobertura90 {np.mean(abs(p-.5)<=.45)*100:.1f}%  roturas VaR95 {np.mean(p<.05)*100:.1f}%")
