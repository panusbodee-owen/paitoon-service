# ADR-003: Risk throttle with explicit halts replaces the all-or-nothing account gate

**Status:** Accepted (supersedes ADR-001 decision 6)
**Date:** 2026-10-16
**Feature:** gold-grid-ea
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
ADR-001 §6 allowed a new basket only if daily-loss and peak-drawdown headroom each fit one **full** X. The user's first Strategy Tester run (XAUUSD, 2024-01 → 2026-07, 500 USD, Robbins preset) stopped trading on 2024-01-10: peak equity 576.40, equity 428.16 → DD used 148.24 + X 25.69 = 173.93 > 172.92 (30% of peak). With no trades, equity never changes, so the gate stays closed forever — a **silent permanent halt** at ~25.7% DD that the hard-stop (30%) never announced. 97% of the test period had no trades.

## Decision
- Budget for a new basket = `min(X, daily room, DD room)` (risk throttle). New baskets still can never cross either limit.
- If DD room < `InpMinRiskFraction` (0.25) × X → explicit **hard-stop** (persisted, notified).
- If daily room < 0.25 × X → explicit **daily pause** until the next server day.
- Mirror: `rgg.basket_risk_budget`; regression test reproduces the user's numbers.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|---|---|---|---|
| Keep gate, add a "halted" message | Minimal change | Still halts at MaxDD − X (≈24% for Robbins), earlier than configured | Surprising; wastes headroom |
| Ignore headroom, rely on hard-stop only | Simplest | A full basket could overshoot the hard-stop by up to X | Breaks "limits cannot be crossed by new entries" |
| Throttle without halting | Keeps trading longest | Tiny budgets → lots below minimum → silent idle again | Same failure mode on small accounts |

## Consequences
### Positive
- No silent stalls; size automatically shrinks in drawdown (anti-martingale behaviour).
### Negative
- Effective hard-stop moves from 30% to 30% − 0.25·X (≈28.5% for Robbins).
### Risks
- Small accounts hit the lot minimum sooner when throttled → counted in `Skipped levels` stats.

## Dependencies
ADR-001 (invariant unchanged).
