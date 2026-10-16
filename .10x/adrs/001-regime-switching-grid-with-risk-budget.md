# ADR-001: Regime-switching grid with hybrid 1:3 RR and a hard basket risk budget

**Status:** Accepted
**Date:** 2026-10-16
**Feature:** gold-grid-ea
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
A grid places several orders at different prices, so a single fixed RR cannot naturally apply to "the trade". The user requires 1:3 RR always, adaptation to sideway and breakout markets, aggressive (Robbins-style) sizing, and good portfolio management. Classic gold grids average down without stops and/or use martingale, which makes tail risk unbounded.

## Decision
1. **Per-order RR is a compile-time constant 3.0.** Every order carries SL = 1R and TP = 3R from placement; R depends on mode (breakout: 1.5×ATR; range: max(0.25×width, 1×ATR)), clamped.
2. **Basket layer** (one trading episode): net (realized + floating) ≤ −X closes everything; ≥ +3X closes everything. Range grids re-arm levels, so the basket layer is what bounds repeated cycles.
3. **Risk budget invariant** checked before every order: realized + Σ P/L@SL(open positions) + Σ P/L@SL(pendings) + P/L@SL(new) ≥ −X. Per-order risk = X/L (breakout) or X/(2L) (range, both sides).
4. **Regime detector** (M15 signal, H1 ADX context) chooses Range Grid (limits, mean-reversion), Breakout Grid (stops, pyramiding), or stand-aside (VOLATILE/NEUTRAL).
5. **Fixed-risk lots**, rounded down; never rounded up to broker minimum.
6. **Account gates** before a new basket: daily-loss and peak-DD headroom must each be ≥ X.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|---|---|---|---|
| Basket-only RR (no per-order SL) | Classic grid feel | Orders without SL; basket can stay open for days; 3X rarely reached | User chose hybrid; unbounded intrabar risk |
| Per-order RR only | Simplest | Range re-arm cycles could compound losses without a cap | No episode-level protection |
| Trend-pullback grid only | Fewer parameters | Doesn't trade sideway | Fails requirement |
| Always-on dual grid | Easy | No adaptation; hedged costs | Fails requirement |
| Martingale lot progression | Fast recovery | Ruin risk on strong gold trends | Conflicts with "manage portfolio well"; user chose fixed risk |

## Consequences
### Positive
- Worst-case loss per basket is known before entry (≈X), daily and peak-DD limits cannot be crossed by new entries.
- RR claim is verifiable per position in the tester.
### Negative
- Many parameters; regime thresholds need user backtesting.
- One basket at a time can miss a breakout that starts while a range basket still has open positions.
- Commission/swap sit outside the price RR (shown on dashboard).
### Risks
- Gaps/slippage can exceed SL → basket stop/daily/hard-stop act as backstops.
- Regime misclassification → per-order SL bounds damage.

## Dependencies
- MT5 hedging account; `OrderCalcProfit` for broker-correct money per price move.
- Constrains: future features must respect the invariant (any new order type goes through the same budget check).
