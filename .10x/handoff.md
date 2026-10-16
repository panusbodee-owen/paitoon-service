# Handoff

**From:** Brainstorming (all roles) → **To:** CTO + PM

- User approved design (3 sections) and asked for a single, ready-to-compile `.mq5` file.
- Spec: `.10x/specs/2026-10-16-gold-grid-ea-design.md`
- Key constraints: MT5 hedging, XAUUSD, RR fixed 3.0 per order + basket, fixed-risk lots (no martingale), regime-switching grid, Robbins (aggressive) preset default.
- Environment limits: no MetaEditor/MT5/wine here → cannot compile MQL5; verification via Python mirror (stdlib unittest) + user-side compile/backtest checklist.
