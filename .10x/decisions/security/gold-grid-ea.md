# Security — gold-grid-ea

- Threat model: local EA, no network/DLL/files; trust boundary = terminal owner.
- Controls: input validation, hedging-only, gold-only guard, magic+symbol scoping, SL-repair, budget denial while SL missing.
- Accepted risks: GV editing by the terminal owner; magic collisions (documented).
- Verdict: no vulnerabilities; approved for tester/demo.

## v2.00
No new surfaces (still no DLL/network/files). Hard-stop now optional/off by user decision — daily losing-trade limit is the primary account guard; setup backstop covers gaps.
