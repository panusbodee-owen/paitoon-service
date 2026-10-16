# DevOps — gold-grid-ea

## CI
`.github/workflows/gold-grid-ea-tests.yml`: Python 3.12, `python -m unittest -v` in `gold-grid-ea/sim`, path-filtered, read-only token. MQL5 cannot be compiled in GitHub-hosted runners (no MetaEditor) → compile is a manual gate.

## Delivery
- Source of truth: branch `claude/gold-grid-ea` → `gold-grid-ea/RobbinsGoldGrid.mq5`; version in `#property version`.
- User installs per README §1 (copy → F7). `.ex5` is gitignored (build artifact, terminal-specific).

## Staged rollout (recommended to user)
1. Strategy Tester, real ticks, 2022→now, each preset; complete README §3 checklist.
2. Demo account ≥ 1 month with the preset intended for live.
3. Live small: Conservative preset 2 weeks.
4. Live target preset (Robbins only if demo DD tolerable).

## Rollback
Keep previous `.ex5` (rename e.g. `RobbinsGoldGrid_v1.00.ex5`). To roll back: remove EA from chart (positions keep server-side SL/TP), attach previous build with **same magic** so it adopts open positions, or close manually.
