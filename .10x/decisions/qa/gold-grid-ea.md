# QA — gold-grid-ea

- **Strategy:** pure logic verified through a Python mirror (identical formulas, same names) + randomized tick-level basket simulation; MQL5 checked statically (structure, API signatures, parity script); runtime behaviour delegated to user's Strategy Tester with a written checklist.
- **Coverage:** RR geometry, sizing, invariant, gates, BE, regime, presets, re-arm, gap behaviour (23 tests).
- **Bugs:** 6 found, 6 fixed (see report).
- **Quality gates:** mirror tests green; parity script clean; user compile = 0 errors before demo; tester checklist complete before live.
