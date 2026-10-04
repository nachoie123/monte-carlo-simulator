#!/usr/bin/env python3
"""Monte Carlo Stock Simulator — 10.000 futuros posibles de una acción, y un examen
que comprueba si el simulador acierta tanto como dice.

Dos motores, calibrados con los últimos 5 años de rendimientos diarios (en log):
    gbm        Movimiento browniano geométrico (la base de Black-Scholes). Cada día sale
               de una campana normal N(media, desviación):
                   S_T = S_0 · exp((μ − σ²/2)·T + σ·√T·Z),   Z ~ N(0, 1)
    bootstrap  Sortea BLOQUES de 21 días reales del pasado. No supone campana: los
               crashes de verdad pueden volver a salir, y en racimo (bloques, no días).

El examen (backtest de calibración): se coloca el simulador en fechas pasadas (una cada
21 días), se calibra con los 5 años anteriores y se mira dónde cayó el precio real dentro
de lo simulado (PIT = fracción de simulaciones por debajo del real). Un simulador honesto
deja el 90% de los precios reales dentro de su franja del 90%.

Uso:
    python3 montecarlo.py Apple
    python3 montecarlo.py Inditex --h 3m
"""
import argparse
import logging
import math

import numpy as np
import yfinance as yf

HORIZONS = {"1m": 21, "3m": 63, "1y": 252}
CAL = 1260        # ventana de calibración: 5 años de bolsa
BLOCK = 21        # bloque del bootstrap: un mes de bolsa
N_PATHS = 10_000
N_EXAM = 2_000    # caminos por fecha en el examen (bootstrap)
STEP = 21         # una fecha de examen cada mes
YEARS_MAX = 20
SEED = 7
BANDS = (5, 25, 50, 75, 95)
LEVELS = (0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95)  # curva "prometido vs real"
ENGINES = ("gbm", "bootstrap")


def phi(x):
    """CDF de la normal estándar (sin scipy)."""
    return 0.5 * math.erfc(-x / math.sqrt(2))


# ---------- motores: devuelven rendimientos diarios en log, forma (n, días) ----------

def sim_gbm(r, days, n, rng):
    return rng.normal(r.mean(), r.std(ddof=1), (n, days))


def sim_bootstrap(r, days, n, rng, block=BLOCK):
    k = -(-days // block)                                  # bloques necesarios
    starts = rng.integers(0, len(r) - block + 1, (n, k))
    idx = (starts[:, :, None] + np.arange(block)).reshape(n, -1)[:, :days]
    return r[idx]


logging.getLogger("yfinance").setLevel(logging.CRITICAL)  # sus 404 de búsqueda no son errores nuestros

SIM = {"gbm": sim_gbm, "bootstrap": sim_bootstrap}


# ---------- datos ----------

def load(ticker):
    """Precios ajustados (máx. 20 años), moneda y dinero movido al día (para elegir bolsa)."""
    t = yf.Ticker(ticker)
    h = t.history(period="max", auto_adjust=True)
    close = h["Close"].dropna() if len(h) else h
    close = close[close > 0]
    if close.empty:
        raise ValueError(f"Sin datos para '{ticker}'.")
    close = close[close.index >= close.index[-1] - np.timedelta64(365 * YEARS_MAX, "D")]
    if len(close) < CAL + HORIZONS["1y"] + 10 * STEP:
        raise ValueError(f"'{ticker}' tiene poco histórico ({len(close)} días; hacen falta ~6,5 años).")
    r = np.diff(np.log(close.to_numpy()))[-CAL:]
    if (r == 0).mean() > 0.10 or np.abs(r).max() > 0.7:
        # bolsa secundaria sin negociación real o con precios erróneos (p.ej. Inditex en Hannover)
        raise ValueError(f"'{ticker}': serie poco fiable (días sin cambio o saltos imposibles).")
    try:
        currency = t.fast_info.get("currency") or ""
    except Exception:
        currency = ""
    traded = float(h["Volume"].tail(250).median() * close.iloc[-1])
    return close, currency, traded


def search_symbols(query, limit=8):
    """Símbolos (acciones y ETF) que Yahoo devuelve para un texto libre. Copiado de 01-capm."""
    try:
        quotes = yf.Search(query, max_results=10).quotes
    except Exception:
        return []
    return [(q["symbol"], q.get("shortname") or q.get("longname") or q["symbol"]) for q in quotes
            if q.get("quoteType") in ("EQUITY", "ETF") and q.get("symbol")][:limit]


def resolve(query):
    """'Inditex', 'ITX.MC' o 'Apple' -> (símbolo, nombre, precios, moneda).
    Un ticker exacto se respeta. Si es un nombre, de todas las bolsas que devuelve Yahoo
    se queda con la que más dinero mueve y tiene datos limpios."""
    query = (query or "").strip()
    if not query:
        raise ValueError("Escribe el nombre o el ticker de una empresa.")
    try:
        close, cur, _ = load(query.upper())
        return query.upper(), query.upper(), close, cur
    except Exception:
        pass
    best = None
    for sym, name in search_symbols(query):
        try:
            close, cur, traded = load(sym)
        except Exception:
            continue
        if best is None or traded > best[0]:
            best = (traded, sym, name, close, cur)
    if best is None:
        raise ValueError(f"No encontré una acción con histórico suficiente y datos limpios para "
                         f"'{query}'. Prueba con el ticker exacto (p.ej. ITX.MC).")
    return best[1:]


# ---------- análisis ----------

def fat_tails(r):
    """Cuánto se aleja la realidad de la campana: curtosis y días de más de ±4σ (las dos colas)."""
    m, s = r.mean(), r.std(ddof=1)
    z = (r - m) / s
    edges = np.linspace(-6, 6, 49)
    counts, _ = np.histogram(np.clip(z, -6, 6), edges)
    mid = (edges[:-1] + edges[1:]) / 2
    width = edges[1] - edges[0]
    normal = len(z) * width * np.exp(-mid ** 2 / 2) / math.sqrt(2 * math.pi)
    return {
        "n_days": int(len(r)),
        "excess_kurtosis": float((z ** 4).mean() - 3),
        "crash_days_real": int((np.abs(z) > 4).sum()),
        "crash_days_normal": float(len(z) * 2 * phi(-4)),
        "worst_day": float(math.expm1(r.min())),
        "hist": {"mid": mid.round(3).tolist(), "real": counts.tolist(),
                 "normal": normal.round(2).tolist()},
    }


def summarize(paths, s0):
    """Cono, cifras de riesgo y unos caminos de muestra a partir de (n, días+1) precios."""
    term = paths[:, -1]
    ret = term / s0 - 1
    q5 = np.quantile(ret, 0.05)
    dd = 1 - paths / np.maximum.accumulate(paths, axis=1)
    return {
        "bands": {str(p): np.percentile(paths, p, axis=0).round(4).tolist() for p in BANDS},
        "samples": paths[:40].round(4).tolist(),
        "median": float(np.median(term)),
        "p_up": float((ret > 0).mean()),
        "var95": float(-q5),
        "es95": float(-ret[ret <= q5].mean()),
        "max_dd_median": float(np.median(dd.max(axis=1))),
        "terminal": term,
    }


def simulate(r, s0, days, n=N_PATHS, seed=SEED):
    rng = np.random.default_rng(seed)
    out = {}
    for eng in ENGINES:
        logp = np.cumsum(SIM[eng](r, days, n, rng), axis=1)
        paths = s0 * np.exp(np.hstack([np.zeros((n, 1)), logp]))
        out[eng] = summarize(paths, s0)
    # histograma del precio final con los mismos cortes para los dos motores
    both = np.concatenate([out[e].pop("terminal") for e in ENGINES])
    edges = np.linspace(*np.percentile(both, [0.5, 99.5]), 41)
    for i, eng in enumerate(ENGINES):
        counts, _ = np.histogram(both[i * n:(i + 1) * n], edges)
        out[eng]["hist"] = counts.tolist()
    out["hist_edges"] = edges.round(4).tolist()
    return out


def exam(r, days, cal=CAL, step=STEP, n=N_EXAM, seed=SEED):
    """Backtest de calibración. Devuelve PITs por motor y la cobertura real por nivel.
    Trabaja con la suma de log-rendimientos: comparar eso equivale a comparar precios."""
    rng = np.random.default_rng(seed)
    pit = {e: [] for e in ENGINES}
    dates = []
    for t in range(cal, len(r) - days + 1, step):
        w, real = r[t - cal:t], r[t:t + days].sum()
        m, s = w.mean(), w.std(ddof=1)
        pit["gbm"].append(phi((real - days * m) / (s * math.sqrt(days))))  # lognormal exacta
        pit["bootstrap"].append(float((sim_bootstrap(w, days, n, rng).sum(1) < real).mean()))
        dates.append(t)
    res = {"origins": len(dates), "independent": round(len(dates) * step / days, 1), "idx": dates}
    for e in ENGINES:
        p = np.array(pit[e])
        res[e] = {
            "pit": p.round(4).tolist(),
            "coverage": {str(L): float((np.abs(p - 0.5) <= L / 2).mean()) for L in LEVELS},
            "miss_low": float((p < 0.05).mean()),     # cayó por debajo del 5% (peor de lo previsto)
            "miss_high": float((p > 0.95).mean()),
        }
    return res


def analyze(query, horizon="3m"):
    if horizon not in HORIZONS:
        raise ValueError(f"Horizonte '{horizon}': usa 1m, 3m o 1y.")
    days = HORIZONS[horizon]
    sym, name, close, cur = resolve(query)
    r = np.diff(np.log(close.to_numpy()))
    w = r[-CAL:]
    s0 = float(close.iloc[-1])
    ex = exam(r, days)
    ex["dates"] = [close.index[t].strftime("%Y-%m-%d") for t in ex.pop("idx")]  # r[t] parte del cierre t
    out = {
        "symbol": sym, "name": name, "currency": cur, "horizon": horizon, "days": days,
        "s0": s0, "last_date": close.index[-1].strftime("%Y-%m-%d"),
        "history_from": close.index[0].strftime("%Y-%m-%d"),
        "mu_annual": float(w.mean() * 252 + w.var(ddof=1) * 252 / 2),   # μ de la fórmula
        "sigma_annual": float(w.std(ddof=1) * math.sqrt(252)),
        "tails": fat_tails(r),
        "sim": simulate(w, s0, days),
        "exam": ex,
        "n_paths": N_PATHS,
    }
    if query.strip().upper() != sym:
        out["resolved_from"] = query
    return out


SHOW = (0.5, 0.8, 0.9, 0.95)


def report(d):
    pct = lambda x: f"{x * 100:5.1f}%"
    print(f"\n{d['name']} ({d['symbol']}) · {d['s0']:.2f} {d['currency']} · horizonte {d['horizon']}")
    print(f"μ anual {pct(d['mu_annual'])}   σ anual {pct(d['sigma_annual'])}   "
          f"curtosis extra {d['tails']['excess_kurtosis']:.1f}   "
          f"días de ±4σ: {d['tails']['crash_days_real']} reales vs {d['tails']['crash_days_normal']:.2f} con campana")
    print(f"{'':12}{'mediana':>10}{'P(ganar)':>10}{'VaR95':>8}{'ES95':>8}{'caída máx':>11}")
    for e in ENGINES:
        s = d["sim"][e]
        print(f"{e:12}{s['median']:10.2f}{pct(s['p_up']):>10}{pct(s['var95']):>8}{pct(s['es95']):>8}"
              f"{pct(s['max_dd_median']):>11}")
    ex = d["exam"]
    print(f"\nExamen: {ex['origins']} fechas ({ex['independent']} independientes de verdad)")
    print(f"{'':12}" + "".join(f"{'dijo ' + str(int(L * 100)) + '%':>11}" for L in SHOW) + "   bajo/sobre")
    for e in ENGINES:
        c = ex[e]
        print(f"{e:12}" + "".join(f"{pct(c['coverage'][str(L)]):>11}" for L in SHOW)
              + f"   {pct(c['miss_low'])}/{pct(c['miss_high'])}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("query", help="nombre o ticker: Apple, ITX.MC, Inditex…")
    ap.add_argument("--h", default="3m", choices=list(HORIZONS))
    a = ap.parse_args()
    report(analyze(a.query, a.h))


if __name__ == "__main__":
    main()
