# Handoff

**From:** SDE (+ DBA) → **To:** QA + Security

## Built
`gold-grid-ea/` — single-file EA `RobbinsGoldGrid.mq5`, 3 presets, Python mirror + 23 tests (all passing), Thai README. Deviations listed in `.10x/decisions/sde/gold-grid-ea.md`.

## Please verify
- QA: mirror ↔ MQL5 formula parity; restart behaviour; filters; invariants; RR exactness; compile-risk review of MQL5 APIs.
- Security: no DLL/WebRequest/file I/O; input validation; magic/symbol isolation; GV tampering impact; notification content.
