# EM — gold-grid-ea

## Tasks (ordered)
| # | Task | Est | Depends |
|---|---|---|---|
| T1 | Python mirror `sim/rgg.py`: levels, RR, lots, budget, gates, regime classifier | 2h | spec |
| T2 | `sim/test_rgg.py` unittest incl. randomized basket simulation | 2h | T1 |
| T3 | MQL5 skeleton: inputs, presets, validation, handles, state persistence | 2h | ADR-002 |
| T4 | MQL5 regime detector | 1.5h | T3 |
| T5 | MQL5 risk manager + executor | 2h | T3 |
| T6 | MQL5 grid engine (breakout, range, re-arm, expiry, cancel) | 3h | T4,T5 |
| T7 | MQL5 guards (basket, daily, hard-stop, BE, SL repair, filters) + dashboard | 2h | T5,T6 |
| T8 | Presets `.set` ×3, Thai README (install/compile/test/runbook) | 1.5h | T7 |
| T9 | Static review pass of MQL5 vs API docs + spec cross-check | 1h | T7 |

## Risks
- **R1 (high):** cannot compile MQL5 here → careful API use, review pass T9, user feedback loop.
- **R2:** sim/MQL5 drift → same names/formulas, cross-check in T9.
- **R3:** broker variance (filling, stop level, GTC) → fallbacks in executor.
