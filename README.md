# Monte Carlo Stock Simulator — and an exam for the simulator

Quantum project #5. The classic quant starter project (simulate thousands of
price paths, read off VaR and the probability of a gain), plus the part most
versions skip: **checking whether the simulator's promises come true.**

A Monte Carlo cone says "90% of the time the price will land in here". That's
a forecast you can grade, the way you grade a weather forecaster: not on one
day, but on whether it rains 70% of the times they say "70%". This project
puts the simulator at ~180 past dates, calibrates it on the 5 years before each
one, and counts how often reality landed inside each band.

## Two engines

| Engine | What it assumes | How a day is drawn |
|---|---|---|
| **GBM** (geometric Brownian motion, the model under Black–Scholes) | Daily log returns are normal with constant μ and σ | `S_T = S_0 · exp((μ − σ²/2)T + σ√T·Z)`, `Z ~ N(0,1)` |
| **Block bootstrap** | Nothing about the shape: the future is made of pieces of the past | Real 21-day blocks from the last 5 years, resampled with replacement. Blocks rather than single days, so volatility clusters survive |

Both run 10,000 paths with a fixed seed and report the cone (5/25/50/75/95%),
the median, P(gain), VaR 95%, Expected Shortfall 95% and the typical max drawdown.

## The exam (calibration backtest)

For every origin date, one per month over ~15 years (20 years of data; the first 5 only calibrate):

1. Calibrate on the 1,260 trading days before it.
2. Compute the **PIT**: the fraction of simulated outcomes below what actually happened.
   GBM's PIT is exact from the lognormal CDF; the bootstrap's comes from 2,000 paths.
3. A calibrated model has uniform PITs, so its central X% band catches reality X% of the time.

## Result (1-month horizon, ~180 independent tests per stock)

| Ticker | History | Tests | GBM says 50% | Bootstrap says 50% | GBM says 90% | Bootstrap says 90% |
|---|---|---|---|---|---|---|
| SPY | 2006–2026 | 179 | 73% | 54% | 96% | 91% |
| AAPL | 2006–2026 | 179 | 56% | 52% | 95% | 91% |
| KO | 2006–2026 | 179 | 60% | 46% | 93% | 90% |
| ITX.MC | 2006–2026 | 183 | 57% | 50% | 93% | 89% |

With 180 independent tests, luck alone moves a coverage figure by about ±7 points
at 50% and ±4.4 points at 90% (95% binomial interval). Read against that:

- **GBM gets the size of the risk right and its shape wrong.** It matches σ, but
  returns are fat-tailed (excess kurtosis 7–16 here): most days are calmer than
  the normal says and a few are far wilder. So its bands are too wide in the
  middle. On SPY the "50%" band catches 73% of outcomes and the "90%" band catches
  96%. Both are well outside the noise.
- **The block bootstrap is calibrated** on all four stocks, within noise at every level.
- **At a 1-year horizon the exam has little power.** ~15 years of test dates hold only ~14
  non-overlapping years, so the web UI says this outright instead of drawing conclusions.

## Validation on 16 stocks (`python3 validar.py`)

The four-stock table could be cherry-picked, so the exam was rerun on 16 US, Spanish and UK
stocks and ETFs at a 1-month horizon, with the two tests a risk team would ask for:

- **Kupiec test** on 95% VaR breaches. This is the Basel backtest; p < 0.05 means the model fails.
- **Kolmogorov–Smirnov** on the PITs. A calibrated model spreads them uniformly between 0 and 1.

| | Inside 50% band | Inside 90% band | VaR 95% breaches | Kupiec fails | KS fails (p < 0.05) |
|---|---|---|---|---|---|
| GBM | 61.9% | 93.6% | 3.5% | 1 / 16 (JPM) | **8 / 16** |
| Block bootstrap | 51.6% | 89.7% | 4.9% | 0 / 16 | **0 / 16** |

The bootstrap passes everywhere. GBM fails the shape test on half the stocks, but VaR alone
almost never catches it: its breaches come out a bit low (3.5%, so it is conservative), which
Kupiec forgives. That's the case for checking the full distribution and not only one quantile.
The pooled figures overlap in time across stocks, so treat them as a summary, not as 2,877
independent tests.

Correctness checks in `test_montecarlo.py` (offline): the exam scores ~90% on data that really
is a bell curve, and simulated GBM matches its closed-form lognormal P(gain) and median within
sampling error. An independent review found no look-ahead in the backtest.

## What it does not do

- **It doesn't forecast direction.** μ is the 5-year mean return, which is mostly noise. The width of the cone is the information.
- **Volatility is constant within each run.** After a crash it isn't, and modelling that is GARCH (Quantum project on volatility).
- **Survivorship bias.** Only stocks that still trade can be examined.
- **Overlapping origins** at 3-month and 1-year horizons, so the UI reports the effective number of independent tests.

## Run it

```bash
pip install -r requirements.txt
python3 test_montecarlo.py           # offline check: the exam passes a GBM on GBM data
python3 montecarlo.py Apple --h 1m   # CLI report
python3 server.py                    # web explainer at http://localhost:8000
```

Search works by name ("Repsol", "Inditex") or exact ticker (`ITX.MC`). When a name
matches several listings, it picks the most traded one with clean data and
skips secondary exchanges with frozen or broken prices.

Files: `montecarlo.py` (engines, exam, CLI), `server.py` (stdlib server),
`docs/demo/index.html` (six-step explainer; on GitHub Pages it reads the precomputed results in `docs/demo/data/`), `test_montecarlo.py`.

Data: Yahoo Finance, split- and dividend-adjusted. Not investment advice.
