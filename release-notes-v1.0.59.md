## v1.0.59 - Config stability and code quality

This release fixes config file encoding bugs that could corrupt game settings, restores missing status reporting for Windows optimizations, and cleans up internal code quality.

### Bug Fixes
- **Fixed UTF-8 BOM encoding** in CS2, Rust, Rainbow Six Siege, and Dota 2 config writers. PowerShell's `Set-Content -Encoding UTF8` was injecting a byte-order mark that could break game config parsers. Replaced with BOM-free UTF-8 output.
- **Fixed Windows optimization status reporting** — the 12 optimization sections (power plan, HAGS, Game Mode, MMCSS, network, etc.) were emitting status markers in the wrong format, causing the app UI to silently drop all per-section pass/fail indicators.
- **Fixed GPU optimization script** using a stale copy of the status marker function instead of the shared engine.

### Code Quality
- Deduplicated TypeScript type definitions across 3 files (handlers, updater, SCEWIN parser) — single source of truth in `src/types/index.ts`.
- Extracted 14 duplicate Pester test helpers into shared definitions, removing ~230 lines of copy-pasted code.
