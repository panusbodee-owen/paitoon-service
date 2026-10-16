# Handoff

**From:** SDE/QA (iteration 4, v2.00) → **To:** User, then Research

- v2.00 = Trend + Pullback + Confirm grid, fixed money risk (5/15), stop after 3 losing trades/day, hard-stop off, no daily target (ADR-005, spec v2).
- Ask user: compile (F7) and backtest XAUUSD M15 2024→now with real ticks; send report + `[RGG]` lines (reason histogram, per-layer TP rate). TP rate > 25% after costs = edge.
- Tuning knobs if too few signals: `InpADXMin`, `InpRSIPullback`, `InpPullbackBars`. M15 CSV export still the fastest path to offline parameter research.
