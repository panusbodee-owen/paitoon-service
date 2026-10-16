# Project Status — gold-grid-ea

| Phase | Status |
|---|---|
| 0. Brainstorming | ✅ Complete — spec `.10x/specs/2026-10-16-gold-grid-ea-design.md` |
| 1. Strategy | ✅ Complete — build verdict, user stories |
| 2. Design | ✅ Complete — ADR-001, ADR-002 |
| 3. Planning | ✅ Complete — T1–T9 |
| 4. Implementation | ✅ Complete — EA, presets, sim, README |
| 5. Verification | ✅ Complete — 23/23 tests, 6 bugs fixed, security OK |
| 6. Delivery | ✅ Complete — CI for mirror tests, rollout + rollback, runbook |

**Current phase:** Delivery Complete — final sign-off (pending user compile)
**Release readiness:** v1.00 for Strategy Tester + Demo; live only after user compile + checklist
**Blockers:** none

## Tasks
- [x] T1 Python mirror
- [x] T2 Python tests
- [x] T3 MQL5 skeleton/state
- [x] T4 Regime detector
- [x] T5 Risk + executor
- [x] T6 Grid engine
- [x] T7 Guards + dashboard
- [x] T8 Presets + README
- [x] T9 Static review

## Iteration 2 — v1.10 (2026-10-16)
- Trigger: user backtest #1 (−14.4%, EA stopped trading 2024-01-10). Analysis: `.10x/reviews/2026-10-16-backtest-1-analysis.md`
- [x] ADR-003 risk throttle + explicit halts
- [x] Tester exit statistics + OnTester criterion
- [x] Mirror + 4 new tests (27/27 pass)
- [x] README research mode, changelog
- [ ] User re-runs backtest in research mode (v1.10)
- [ ] Entry-edge research (needs exported M15 data)

## Iteration 3 — v1.20 (2026-10-16)
- Trigger: user wants ≥ 5%/day on 10,000 USD, "remove losses". Discussed; user chose daily target + keep SL + X = remaining target / 3.
- [x] ADR-004, EA v1.20, mirror + 3 tests (30/30), presets, README, `sim/risk_table.py`
- [ ] User compiles v1.20 and backtests (10,000 USD, target 5 and target 0 runs)
- [ ] Entry-edge research (needs exported M15 data)

## Iteration 4 — v2.0 (2026-10-16)
- Trigger: user requirements 1–7 (remove 30% stop, 30–10k accounts, lose 5/win 15, stop after 3 losses/day, M15 smarter entries, precise grid).
- Decisions: fixed money risk, no daily target, Trend + Pullback + Confirm. Spec `.10x/specs/2026-10-16-gold-grid-ea-v2-design.md`, ADR-005.
- [x] Mirror (rgg.py, setup_sim.py) + 24 tests
- [x] EA v2.00
- [x] README v2, default preset
- [x] QA review + push
- [ ] User compiles v2.00 and backtests M15 2024→now; send `[RGG]` Journal stats
