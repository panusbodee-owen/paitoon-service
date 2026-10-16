# QA — gold-grid-ea

- **Strategy:** pure logic verified through a Python mirror (identical formulas, same names) + randomized tick-level basket simulation; MQL5 checked statically (structure, API signatures, parity script); runtime behaviour delegated to user's Strategy Tester with a written checklist.
- **Coverage:** RR geometry, sizing, invariant, gates, BE, regime, presets, re-arm, gap behaviour (23 tests).
- **Bugs:** 6 found, 6 fixed (see report).
- **Quality gates:** mirror tests green; parity script clean; user compile = 0 errors before demo; tester checklist complete before live.

## v1.10
- 27 tests pass (+4: throttle full/partial, explicit halts, 5,000-case property test that throttled budgets never cross daily/DD limits, regression with the user's backtest numbers).
- Lesson: the v1.00 tests asserted the gate's arithmetic but no test asked "can the EA get stuck forever?" — liveness of guards is now covered.

## v1.20
- 30 tests pass (+3: aligned X for 10k/5% incl. near-target stop; 5,000-case property: X ≤ target/3 and a full win never overshoots the target; daily target boundary).

## v2.00
- Mirror rewritten (`rgg.py`) + `setup_sim.py` (day simulation); 24 tests pass: layer RR (5,000 random), shared-SL layer geometry, RR repair after slippage, fixed-money sizing incl. the user's 30$ example and 10k scaling, skip-not-round-up, layers capped by remaining losses, candle patterns, signal conditions + every rejection reason (buy/sell), 300 simulated days (30$ and 10k) — every trade −1R/+3R within risk, losses/day ≤ 3.
- Static: brace/paren balance, no undefined/duplicate functions, 6 signal params parity-checked against the mirror, README example table recomputed by the mirror.
- 2 test-expectation bugs found and fixed (a "flat" candle that was really a pin bar; small-account lots can exceed 0.01 when the SL is tight).
- Not verifiable here: compile, live/tester behaviour, entry edge.
