# SRE — gold-grid-ea

## Reliability objectives (live)
| Objective | Target | How observed |
|---|---|---|
| Every position carries SL & TP | 100% (repaired within 1 tick) | Experts log `Repaired missing SL`; History tab |
| Per-order RR | 3.00 ± 0.01 | History: |TP−E| / |E−SL| |
| Basket loss ≤ X (no gap) | 100% | `Basket END ... realized` log lines |
| Terminal uptime during session (07–21 server) | ≥ 99.5% | VPS monitoring / MT5 journal |

## Monitoring & alerts
- On-chart dashboard (regime, basket net, day P/L, DD, status).
- `Alert` + optional push (`InpPushAlerts`) on: basket stop/target, daily loss limit, equity hard-stop.
- Logs: prefix `[RGG]` in Experts tab; grep `Pending rejected`, `failed`, `HARD-STOP`.

## Failure modes → response (full runbook: README §5)
- Hard-stop: EA flat + halted (persisted). Human review required; reset via `InpResetHardStop`.
- Daily limit: auto-resume next server day.
- Restart/VPS reboot: stateless re-read + persisted regime/basket; positions protected server-side.
- Repeated rejects: broker filling/stop-level mismatch → collect log, adjust.

## Known residual risks
Weekend/news gaps through SL (opt-in `InpCloseAllFriday`), commission/swap outside price RR, simultaneous-fill margin.
