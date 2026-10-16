# Backtest #1 analysis (user run, 2026-10-16)

**Setup (from screenshots):** XAUUSD, M15 bars 64,506 (2024-01-01 → ~2026-07), real ticks 99% quality, deposit 500 USD, preset Robbins, EA v1.00.

| Metric | Value |
|---|---|
| Net profit | −71.84 (−14.4%) |
| Trades | 39 (all between 2024-01-01 and 2024-01-10) |
| Win rate | 38.5% (15/39) |
| Avg win / avg loss | 7.15 / −7.46 → wins average ≈ 1R, not 3R |
| Max equity DD | 153.55 (26.64%) |
| PF | 0.60 |

## Findings
1. **[Bug, fixed in v1.10] Silent permanent stall.** Account gate blocked new baskets once DD used + X > 30% of peak (173.93 > 172.92). No trades for the remaining ~2.5 years. → ADR-003.
2. **Sample too small to judge the strategy.** 39 trades over 10 days; conclusions about edge are not statistically meaningful.
3. **Few full 3R wins.** Decomposition of 107.30 gross profit over 15 wins with largest win 26.71 ≈ 3R implies ~4 TP hits and ~11 small wins (break-even exits at +0.05R). 24 of 39 trades lost 1R. For a driftless walk P(+1R first) ≈ 50% and P(3R | +1R, BE) ≈ 1/3; observed 38% and ~27% → consistent with entries having **no edge** plus spread cost. RR alone cannot create profit; 1:3 needs > 25% TP rate after costs.
4. **Account too small for the sizing model.** 0.01 lot = 1 USD per 1 USD move; R ≈ 3–9 USD; per-order risk at 500 USD = 10 USD (breakout) / 5 USD (range) → coarse lots, range levels skipped.

## Next steps
- v1.10: re-run in research mode (README §3.1): Custom 6/50/95, deposit ≥ 3,000 USD, read exit statistics.
- Entry-edge research needs price data; this environment's network blocks data vendors → ask the user to export M15 XAUUSD bars from MT5 (CSV) for an offline research backtester.
