# DBA — gold-grid-ea

No database. Durable state = MT5 terminal **GlobalVariables** (key-value doubles, flushed by the terminal, survive restarts; deleted after 4 weeks without access).

## Key schema — prefix `RGG.<symbol>.<magic>.` (tester: `RGGT.`)
| Key | Type (stored as double) | Meaning |
|---|---|---|
| peak | money | Peak equity for hard-stop |
| dayStamp / dayEq | datetime / money | Server day + equity at day start |
| dHalt / hHalt | 0/1 | Daily halt / hard halt |
| cool | datetime | Cooldown end |
| bAct, bType, bDir, bStart, bEq, bRisk, bR, bLow, bHigh, bFrz | mixed | Active basket |
| rg, rgC, rgN, rgBO, rgBS, rgBT, rgBar | mixed | Regime state machine |

## Source of truth rules
- Orders/positions are **never** cached as truth: always re-read from the terminal (magic + symbol scope).
- Realized basket P/L = deal history since `bStart` (recomputed on `DEAL_ADD`).
- Name length: longest key ≈ prefix(≤40) + 5 < 63-char GV limit for symbols up to ~25 chars.
- Isolation: different magic numbers → disjoint key spaces (multiple charts/accounts safe).
