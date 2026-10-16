# ADR-004: Daily profit target with target-aligned basket risk

**Status:** Accepted
**Date:** 2026-10-16
**Feature:** gold-grid-ea
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
User (capital 10,000 USD) asked to "remove losses" and require ≥ 5% profit per day. After discussion (5%/day compounded ≈ +165%/month; removing SL hides losses and voids the 1:3 RR) the user chose: (1) a daily target of +5% that locks the day, and (2) more risk while keeping SL. Numbers (`sim/risk_table.py`) showed that once the day's upside is capped at 5%, any basket risk X above 5%/3 = 1.67% worsens the real RR (X = 6% → 1:0.83, needs 54.5% wins; X = 10% → 1:0.5). The user chose X = remaining target / 3.

## Decision
- `InpDailyTargetPct` (default 5): equity ≥ day-start × (1 + T) → close all, cancel pendings, no new baskets until the next server day (flag persisted).
- `InpAlignRiskToTarget` (default true): new-basket cap = min(preset X, (T·dayStart − max(0, dayP/L)) / 3). Losing days never raise X above T/3 (no loss chasing). If the aligned cap < 10% of T/3 → no new basket that day ("close to daily target").
- Order of limits: halts (ADR-003) → target cap → daily/DD throttle.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|---|---|---|---|
| Remove SL / ignore losses | Matches literal ask | Unbounded loss, no RR, ruin on one trend move | Rejected with user |
| Daily target with preset X (6%) | Bigger days possible | Real RR 1:0.83 | Asymmetric against the user |
| Recover-to-target sizing (raise X on red days) | Hits target more often | Martingale by another name | Conflicts with no-martingale decision |

## Consequences
### Positive
- 1:3 preserved under a capped day; a full winning basket ends the day exactly at the target.
### Negative
- Full 5% days require a complete winning basket (or several) — they will be uncommon; the target is a ceiling, not a promise.
- Closing at the target can exit positions before their own SL/TP.
### Risks
- Users may read "5%/day" as expected return → README states it is a cap.

## Dependencies
ADR-001 (invariant), ADR-003 (throttle/halts).
