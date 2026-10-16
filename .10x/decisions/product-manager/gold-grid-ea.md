# PM — gold-grid-ea

## User
Thai trader/consultant running MT5 on a hedging account, trading XAUUSD; capital size irrelevant; wants aggressive but managed risk.

## User stories
1. As a trader, every order the EA opens has SL = 1R and TP = 3R so my per-trade RR is always 1:3.
2. As a trader, the whole grid (basket) is capped at −X% and banks profit at +3X% of equity.
3. As a trader, the EA trades mean-reversion in sideway markets and momentum in breakouts, and stands aside when volatility spikes.
4. As a trader, a daily loss limit and an equity hard-stop protect the account even if the strategy misbehaves.
5. As a trader, I pick Conservative / Balanced / Robbins / Custom risk with one input.
6. As a trader, I get one `.mq5` file I can drop into MetaEditor and compile, plus Thai instructions.

## Success criteria
- Compiles in MetaEditor with 0 errors (user-verified).
- In Strategy Tester: every opened position has SL and TP with |TP−E| / |E−SL| = 3.00 ± 0.01.
- Basket worst-case loss never exceeds X (except gaps/slippage); daily and hard-stop limits never breached by new entries.
- Python mirror tests all pass.

## Scope
**In:** regime detector, breakout grid, range grid with re-arm, fixed-risk lots, basket stop/target, daily loss, hard-stop, filters (spread/session/rollover/Friday/news-live), break-even, dashboard, presets, Thai README.
**Out:** MT4, netting, multi-symbol, martingale, profit guarantees, optimisation of parameters (user backtests).
