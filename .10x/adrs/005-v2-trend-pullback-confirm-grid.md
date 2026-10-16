# ADR-005: v2.0 strategy core — Trend + Pullback + Confirm grid, fixed-money risk, loss-count daily stop

**Status:** Accepted — supersedes ADR-001 (regime-switching grid, basket X), ADR-003 (throttle; only the optional hard-stop remains), ADR-004 (daily target)
**Date:** 2026-10-16 · **Feature:** gold-grid-ea · **Author:** 10x-Team

## Context
Backtest #1 showed no entry edge (wins ≈ random-walk odds) and v1.x sizing tied to % baskets. The user restated requirements: fixed money per trade (5 / 15), stop after 3 losing trades per day, no 30% stop, accounts from 30 USD, M15, precise grid entries.

## Decision
- Replace regime detection + range/breakout grids with a single trend-following setup: H1 trend filter → M15 pullback into EMA20/50 with RSI dip → engulfing/pin confirmation → layered entries (market + limits) sharing a structural SL, each with TP = 3R of its own entry.
- Risk unit = fixed money per trade; lot rounded down; skip when the minimum lot already exceeds the risk.
- Daily stop by **count of losing trades**; layers per setup capped by the remaining loss allowance so one setup cannot overshoot the rule.
- Keep invariants: SL on every order, RR exactly 1:3 (TP re-aligned after slippage), worst-case budget check per setup.

## Alternatives Considered
| Alternative | Why not |
|---|---|
| Keep v1 regime engine, add filters | Range/breakout logic showed no edge; user asked for trend pullback |
| Breakout + retest | User chose pullback; can be added later as a second setup |
| Percent risk with min-lot fallback | User chose fixed money |
| Independent SL per layer | Breaks the "structure invalidates the setup" idea; shared SL keeps the thesis clean |

## Consequences
+ Fewer, higher-quality trades; every outcome −1R / +3R; daily loss bounded by 3 × risk.
− Shared SL means layers of one setup usually win or lose together (correlated).
− 30 USD accounts: 0.01 lot = 1 USD per 1 USD move → setups with R > risk money are skipped; margin limits layers at low leverage.
− Edge still unproven until backtested.
