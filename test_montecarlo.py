"""Check sin red: la fórmula del GBM y, sobre todo, que el examen está bien programado.
Si los datos SON una campana, el motor gbm tiene que aprobar con ~90% en su franja del 90%."""
import math

import numpy as np

import montecarlo as mc

rng = np.random.default_rng(0)
m, s = 0.0004, 0.015                      # ~10% y ~24% anual

# 1) GBM: la media del log del precio final es (μ − σ²/2)·T  ==  días · m
r = rng.normal(m, s, 5000)
x = mc.sim_gbm(r, 252, 20000, rng).sum(1)
assert abs(x.mean() - 252 * r.mean()) < 0.01, x.mean()
assert abs(x.std() - math.sqrt(252) * r.std(ddof=1)) < 0.01, x.std()

# 2) bootstrap: solo usa días reales y respeta la longitud pedida
b = mc.sim_bootstrap(r, 50, 100, rng)
assert b.shape == (100, 50) and np.isin(b, r).all()

# 3) el examen sobre datos de campana: cobertura ≈ nivel prometido
ex = mc.exam(rng.normal(m, s, 6000), 21)
for e in mc.ENGINES:
    c = ex[e]["coverage"]["0.9"]
    assert abs(c - 0.90) < 0.06, (e, c)

# 4) y sobre datos con colas gordas (t de Student, 3 g.l.) el gbm NO debe aprobar mejor que el bootstrap
fat = rng.standard_t(3, 6000) * s / math.sqrt(3) + m
ex = mc.exam(fat, 1, step=5)
assert ex["bootstrap"]["coverage"]["0.95"] >= ex["gbm"]["coverage"]["0.95"] - 0.01, ex
print("ok")

# 5) el GBM simulado coincide con su fórmula cerrada (lognormal) dentro del error de muestreo
w = rng.normal(m, s, 1260)
sim = mc.simulate(w, 100.0, 63)["gbm"]
z = w.mean() * 63 / (w.std(ddof=1) * math.sqrt(63))
assert abs(sim["p_up"] - mc.phi(z)) < 0.015, (sim["p_up"], mc.phi(z))
assert abs(sim["median"] / (100 * math.exp(w.mean() * 63)) - 1) < 0.01
print("ok fórmula")
