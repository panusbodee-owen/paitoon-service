# Architect — gold-grid-ea

## Components (sections of one .mq5, see ADR-002)
| Component | Responsibility | Depends on |
|---|---|---|
| Config | inputs, enums, `RR_RATIO = 3.0`, preset resolution | — |
| State | GlobalVariable persistence (peak, day, halts, cooldown, basket) | Config |
| Market utils | price/volume normalization, stop/freeze distance, spread, session/Friday/rollover | Config |
| RegimeDetector | ATR/ADX/BB/Donchian handles → `ENUM_REGIME` with hysteresis and sticky breakout | indicators |
| RiskManager | lot for risk, P/L@SL, worst-case basket, budget check, account gates | OrderCalcProfit |
| Executor | CTrade wrapper: filling fallback, retries, pending time type | CTrade |
| GridEngine | breakout levels, range levels, placement, re-arm, expiry, cancel on regime change | Regime, Risk, Executor |
| Basket/Guards | net P/L, basket stop/target, daily loss, hard-stop, break-even, missing-SL repair | Risk, Executor, State |
| Dashboard | `Comment()` status panel | all (read-only) |

## Data flow (OnTick)
tick → refresh day/peak → hard-stop → daily-loss → position care (SL repair, BE) → basket check → [new M15 bar: regime update + cancel mismatched pendings] → filters → start basket or re-arm (throttled) → dashboard

## Identity
Magic number + symbol scope everything. Comment `RGG|<R|B>|<B|S>|<level>` identifies grid slot; positions inherit the order comment.

## Failure modes
| Failure | Handling |
|---|---|
| Terminal/VPS restart | Stateless re-read of positions/orders; GV restore of basket & guards |
| Broker rejects filling | fallback chain |
| Stops too close | recompute from min distance; if RR breaks → skip |
| Missing SL on a position | set SL/TP; if price already past → close |
| Gap through SL | basket/daily/hard-stop backstops |
| Indicator data not ready | skip bar, no trading |
| Netting account | INIT_FAILED |
