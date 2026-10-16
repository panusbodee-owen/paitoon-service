# Security Review — gold-grid-ea (2026-10-16)

## Attack surface
| Surface | Present? | Notes |
|---|---|---|
| DLL imports | No | `#import` absent |
| Network (`WebRequest`, sockets) | No | Only MT5 Economic Calendar (terminal API) |
| File I/O | No | |
| Secrets/credentials | No | None stored or logged |
| Push notifications | Optional, off by default | Sends symbol + equity numbers to the account owner's MetaQuotes ID only |
| Terminal GlobalVariables | Yes | Local state store |

## Threats & mitigations
| Threat | Impact | Mitigation |
|---|---|---|
| Malformed inputs (e.g. X = 90%, levels = 0) | Excess risk / crash | `ResolvePreset` + `InputsValid` → `INIT_PARAMETERS_INCORRECT` |
| Another EA on same magic + symbol | EA would manage/close foreign positions | Documented: unique `InpMagic` per chart/account |
| Local user edits GVs (e.g. clears `hHalt`) | Bypass hard-stop | Accepted: same trust boundary as the terminal owner; documented reset path is `InpResetHardStop` |
| Order without SL (broker reject/modify) | Unbounded loss | `ManagePositions` repairs SL or closes; budget check denies new orders while any SL is missing |
| Netting account | Grid positions merge, logic invalid | `INIT_FAILED` |
| Running on wrong symbol | Wrong sizing assumptions | Gold-only guard (`InpAllowNonGold` override) |
| Python sim | — | stdlib only, no network, not part of runtime |
| Repo / deploy | — | Pages workflow only builds the Vite app on `main`; `gold-grid-ea/` not bundled |

## Financial-risk (non-security) notes surfaced to user
Gap/slippage beyond SL, commission/swap outside price RR, single basket at a time, per-order margin check.

## Verdict
✅ No vulnerabilities found. Sign-off for tester/demo use.
