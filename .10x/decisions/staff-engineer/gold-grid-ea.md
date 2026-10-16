# Staff Engineer — gold-grid-ea

## Conventions
- MQL5: `Inp*` inputs, `g_*` globals, PascalCase functions, explicit casts (aim 0 compiler warnings), `input group` sections.
- All prices through `NormPrice()` (tick size), all volumes through `NormVolume()` (step, round down).
- No magic numbers in logic; tunables are inputs, the RR is a `#define`.
- Logging: `PrintFormat("[RGG] ...")` for every trade decision and rejection with retcode.
- No DLL imports, no WebRequest, no file I/O.

## Cross-cutting
- Every order path goes through `RiskBudgetAllows()` (ADR-001 invariant).
- Python mirror (`gold-grid-ea/sim/`) uses the same function names (snake_case) and formulas; changes to formulas must be made in both.
- Folder: `gold-grid-ea/` (EA, presets, sim, README). Root site untouched; deploy workflow only builds on `main` and only the Vite app.
