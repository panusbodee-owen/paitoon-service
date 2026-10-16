# Senior Engineer — gold-grid-ea

## Implementation approach
- **Files:** `gold-grid-ea/RobbinsGoldGrid.mq5`, `gold-grid-ea/presets/*.set`, `gold-grid-ea/sim/{rgg.py,test_rgg.py}`, `gold-grid-ea/README.md`.
- **Money math:** use `OrderCalcProfit(ORDER_TYPE_BUY|SELL, sym, vol, open, close, out)`; map pending types to market direction. Never derive from tick value manually (account-currency safe).
- **RR exactness:** normalize entry and SL first, compute TP = E ± 3·|E−SL|, normalize TP, then verify ratio within 0.01; skip if not.
- **Tricky parts:**
  - Pending placement validity: buy limit < Ask − minDist; buy stop > Ask + minDist (mirror for sells). minDist = max(stops level, freeze level)·point + 1 tick.
  - Realized P/L: recompute via `HistorySelect(basketStart, now)` only when `OnTradeTransaction` reports a deal (dirty flag) — avoid per-tick history scans.
  - Break-even must stay stateless: BE applies only while SL is on the losing side of entry.
  - Breakout regime is immediate + sticky; RANGE/NEUTRAL need N confirmations (Donchian window moves, so consecutive breakout confirmation would require an ever-higher close).
  - New-bar detection with `iTime(sym, tf, 0)`; trading maintenance throttled (≥ 15 s or dirty flag).
- **Tester:** Calendar API unavailable in tester → news filter disabled when `MQL_TESTER`.
