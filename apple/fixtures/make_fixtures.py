"""Saca de Yahoo los precios de las 5 empresas de fábrica y guarda lo que el Python calcula con ellos.
MonteCarloKit/Sources/MonteCarloKit/Resources/prices/<sym>.json -> va dentro de la app (recurso del paquete) (fechas + cierres ajustados).
MonteCarloKit/Tests/MonteCarloKitTests/Expected/<sym>-<h>.json -> solo para `swift test`: el Swift tiene que dar estos mismos números."""
import json, math, sys, os
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import montecarlo as mc

HERE = os.path.dirname(os.path.abspath(__file__))
COMPANIES = [("AAPL", "Apple"), ("ITX.MC", "Inditex"), ("NVDA", "Nvidia"), ("REP.MC", "Repsol"), ("SPY", "S&P 500 (SPY)")]
PR = f"{HERE}/../MonteCarloKit/Sources/MonteCarloKit/Resources/prices"; EX = f"{HERE}/../MonteCarloKit/Tests/MonteCarloKitTests/Expected"
os.makedirs(PR, exist_ok=True); os.makedirs(EX, exist_ok=True)
for sym, name in COMPANIES:
    close, cur, _ = mc.load(sym)
    json.dump({"symbol": sym, "name": name, "currency": cur,
               "dates": [d.strftime("%Y-%m-%d") for d in close.index],
               "close": [float(x) for x in close.to_numpy()]},
              open(f"{PR}/{sym}.json", "w"))
    r = np.diff(np.log(close.to_numpy())); w = r[-mc.CAL:]; s0 = float(close.iloc[-1])
    for h, days in mc.HORIZONS.items():
        ex = mc.exam(r, days); ex["dates"] = [close.index[t].strftime("%Y-%m-%d") for t in ex.pop("idx")]
        out = {"s0": s0, "days": days,
               "mu_annual": float(w.mean() * 252 + w.var(ddof=1) * 252 / 2),
               "sigma_annual": float(w.std(ddof=1) * math.sqrt(252)),
               "tails": mc.fat_tails(r), "sim": mc.simulate(w, s0, days), "exam": ex}
        json.dump(out, open(f"{EX}/{sym}-{h}.json", "w"))
    print(sym, cur, len(close), "días", close.index[0].date(), "→", close.index[-1].date(), f"s0={s0:.2f}")
