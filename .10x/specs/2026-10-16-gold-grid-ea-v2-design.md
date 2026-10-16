# Spec v2.0: Robbins Gold Grid — Trend + Pullback + Confirm grid

**Date:** 2026-10-16 · **Feature:** gold-grid-ea · **Supersedes:** strategy core of `2026-10-16-gold-grid-ea-design.md` (v1.x)
**Approved by user (selections):** fixed money risk per trade; no daily profit target; Trend + Pullback + Confirm entries.

## User requirements (verbatim intent)
1. Remove the 30% loss stop. 2. Work for accounts 30–10,000 USD. 3. Per trade: lose 5 / win 15 (1:3). 4. Stop for the day after 3 losing trades, resume next day. 5. M15 chart, smarter chart reading. 6. Small capital accepted by the user. 7. Grid, but precise entries.

## Rules
| Area | Rule (defaults are inputs) |
|---|---|
| Risk | `InpRiskMoney` = 5.0 max loss per trade (account currency); TP = 3 × that trade's own R → win ≈ 15. Lot rounded down; if 0.01 lot already loses more than `InpRiskMoney` the trade is skipped |
| Daily stop | Losing trade = exit deal net < 0. After `InpMaxLossesPerDay` = 3 → close all, no trading until next server day |
| Layers vs losses | Layers per setup = min(`InpGridLevels` = 3, losses remaining today) |
| Hard-stop | `InpMaxDDPct` = 0 (off). Optional |
| Daily target | none |
| Trend (H1, closed bar) | UP: EMA50 > EMA200 and EMA50 rising over 3 bars and ADX(14) ≥ 20. DOWN mirrored. Otherwise no trade |
| Pullback (M15, bars 1..6) | BUY: some bar low ≤ EMA20 (touch), min RSI(14) ≤ 40, bar-1 close > EMA50 (zone held), RSI rising (RSI1 > RSI2). SELL mirrored (high ≥ EMA20, max RSI ≥ 60, close < EMA50, RSI falling) |
| Confirmation (bar 1) | Engulfing (body engulfs previous opposite body) **or** pin bar (wick ≥ 2 × body, wick ≥ 50% range, close in the outer 40%) |
| Volatility | Skip when ATR(14) > 2 × average ATR (96 bars) |
| SL | Beyond the pullback extreme (bars 1..6) ± 0.2 × ATR. Skip if R1 < max(MinSL 1.0, stop level) or R1 > MaxSL 20 or R1 > 3 × ATR |
| Grid | Layer 1: market right after the confirmation bar closes (within 120 s). Layer k (k ≥ 1): limit at E1 ∓ k × 0.3 × R1, same SL, TP = own 3R. Each layer sized to lose ≤ `InpRiskMoney` |
| Setup lifecycle | One setup at a time. Pending layers cancelled when any layer closes, after 8 bars, on trend flip, outside session/news/Friday cutoff. Cooldown 1 bar after flat |
| RR integrity | After fills, TP re-aligned to exactly 3 × |open − SL| (slippage). Break-even off by default (pure −1R/+3R outcomes) |
| Backstop | Setup net (realized + floating) ≤ −Σ layer risk → close all (gaps) |
| Filters | spread ≤ 0.50, session 07–21 server, no 23:00–01:00, Friday ≥ 20:00 no new trades, high-impact USD news (live) |
| Diagnostics | OnTester prints signals found/skipped by reason, per-layer TP/SL/other, days stopped by the loss rule; returns profit / max equity DD |

## Non-goals
Range grid, breakout grid, regime classifier, % presets, daily profit target (all v1.x).
