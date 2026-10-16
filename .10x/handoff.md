# Handoff

**From:** DevOps + SRE → **To:** User / next iteration

- Deliverable: `gold-grid-ea/RobbinsGoldGrid.mq5` (+ presets, README in Thai) on branch `claude/gold-grid-ea`.
- Runbook: `gold-grid-ea/README.md` §5; SRE objectives `.10x/decisions/sre/gold-grid-ea.md`.
- CI: `.github/workflows/gold-grid-ea-tests.yml`.
- Escalation: user sends MetaEditor compile errors / tester logs → fix loop (SDE), re-run mirror tests.
- Open items: (1) user compile result, (2) tester checklist results, (3) parameter tuning after backtests.
