# CTO — gold-grid-ea

## Problem
User (PM/consultant, Thailand) wants an automated gold-trading EA: grid entries, fixed 1:3 RR, adapts to sideway vs breakout, strong portfolio protection, "Robbins World Cup" (aggressive) style.

## Build vs buy
- The referenced "Robbin Cup EA" could not be found (web search, 2026-10-16). Commercial gold grid EAs exist but are closed-source, often martingale, unverifiable.
- **Verdict: BUILD.** Requirements (hybrid RR, no martingale, hard risk invariants) are specific; open source the user controls is the only way to verify risk behaviour.

## Tech direction
- MQL5 / MetaTrader 5, hedging accounts only. Standard library `CTrade` only; no DLLs, no web requests.
- Single self-contained `.mq5` (user requested easy compile).
- Python 3 stdlib mirror for logic verification (no pip deps — none installed in env, and user can run it anywhere).

## Strategic risks
- Trading systems can lose money; no profit guarantee. The deliverable guarantees **rule fidelity** (RR, risk caps), not returns.
- Cannot compile MQL5 in this environment → compile risk transferred to user; mitigated by conservative API use and offer to fix reported compile errors.
