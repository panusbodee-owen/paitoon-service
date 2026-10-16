# ADR-002: Ship the EA as one self-contained .mq5 file

**Status:** Accepted
**Date:** 2026-10-16
**Feature:** gold-grid-ea
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
The approved design listed separate `.mqh` modules under `MQL5/Include/`. On approval the user asked for code that is convenient to compile. Include paths are the most common compile failure for non-developer MT5 users (wrong folder, wrong relative path).

## Decision
Ship `gold-grid-ea/RobbinsGoldGrid.mq5` as a single file, internally sectioned in the same module order as the design (Config → Utils/State → Regime → Risk → Execution → Grid → Basket/Guards → Dashboard → Event handlers). Only standard-library includes (`<Trade\Trade.mqh>`) are used, which ship with every MT5 terminal.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|---|---|---|---|
| Multi-file `.mqh` modules | Cleaner separation, smaller files | Users must copy into two folders correctly | User explicitly asked for easy compile |
| Pre-compiled `.ex5` | Zero compile step | Cannot build here (no MetaEditor); opaque binary | Not possible / not reviewable |

## Consequences
### Positive
- Copy one file to `MQL5/Experts/`, press F7.
### Negative
- Long file (~1.5k lines); navigation via section banners.
### Risks
- Harder to unit-test in MQL5 directly → mitigated by the Python mirror of pure functions.

## Dependencies
- Supersedes the file layout (not the logic) of the spec §1 structure.
