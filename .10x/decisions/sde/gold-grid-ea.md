# SDE — gold-grid-ea (what was built)

## Files
| File | Lines | Purpose |
|---|---|---|
| `gold-grid-ea/RobbinsGoldGrid.mq5` | ~1.7k | Single-file EA (ADR-002), 13 sections |
| `gold-grid-ea/presets/RobbinsGoldGrid_{Conservative,Balanced,Robbins}.set` | — | Preset inputs |
| `gold-grid-ea/sim/rgg.py` | ~260 | Python mirror of pure logic |
| `gold-grid-ea/sim/basket_sim.py` | ~150 | Tick-level basket simulator (invariant checks) |
| `gold-grid-ea/sim/test_rgg.py` | ~260 | 23 unittest cases (stdlib) |
| `gold-grid-ea/README.md` | — | Thai install/compile/backtest/runbook |

## Deviations from spec / plan
1. **Single file** instead of `.mqh` modules (ADR-002, user request).
2. **BREAKOUT is immediate + sticky** (spec §3 already updated): consecutive-bar confirmation is impossible with a moving Donchian window. Breakout baskets may start within `InpBreakoutEntryBars` (2) of the signal, once per breakout event.
3. **Range box min width 4 ATR** (not 3) so TP = 3R fits inside the box.
4. **Frozen basket**: once the regime leaves the basket's mode, the basket never re-arms again (stale box protection); it ends when flat.
5. **Added `InpCloseAllFriday` (default false)**: the gap simulation showed a 40$ gap through SLs can cost ≈6.7X; closing before the weekend is offered as opt-in because a Friday close exits outside 1:3.
6. **Regime state persisted** (GV) + advance-once-per-bar guard: found in self-review — without it, a chart timeframe change would reset the regime to NEUTRAL and cancel an active grid.
7. **Recent-order buffer** (`g_recent`, 10 s TTL): covers the MT5 window where a just-placed order is not yet in `OrdersTotal()`, so the risk budget never undercounts.
8. **AbortBasketStart**: failed starts wait one signal bar (prevents log spam when lots are below broker minimum).
9. News window also cancels pendings immediately (not only at bar close).

## Tech debt
- MQL5 not compiled in this environment (no MetaEditor) — **user must compile**; first compile errors (if any) to be fixed in a follow-up.
- Python mirror ignores commission/swap; MQL5 includes them in realized/worst case.
- `MarginOk` checks one order at a time; simultaneous fills of several pendings could need more margin.
- Dashboard via `Comment()` (simple, not styled).

## v1.10 (after user backtest #1)
- Replaced `AccountGateOk` with `BasketRiskBudget` (ADR-003): throttle X to headroom; explicit hard-stop/daily pause below `InpMinRiskFraction` (0.25) of X.
- `TryStartBasket` computes the budget only when a basket would actually start (no log spam).
- Tester diagnostics: `PrintExitStats()` from `OnTester()` — per grid type TP / SL / BE / EA-close counts and P/L, regime share, skipped levels; `OnTester` returns profit ÷ max equity DD for "Custom max" optimisation.
- Version 1.10. README §3.1 research mode + changelog.

## v1.20 (user: capital 10,000, wants ≥5%/day)
- `InpDailyTargetPct` (5) + `CheckDailyTarget` (persisted `dTgt`, close-all, done for the day) and `InpAlignRiskToTarget` (X cap = remaining target / 3, no loss chasing) — ADR-004.
- Budget order: halts → target cap → daily/DD throttle; throttle log only when daily/DD rooms bind.
- Dashboard target line + "DONE FOR TODAY" status; stats count target days. Presets carry the new inputs. `sim/risk_table.py` documents the trade-off.
