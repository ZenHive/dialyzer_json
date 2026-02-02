# Changelog

Completed roadmap tasks. For upcoming work, see [ROADMAP.md](ROADMAP.md).

---

## Phase 1: Core Foundation

### Initial Implementation
**Completed** | Session 1

**What was done:**
- Created `mix dialyzer.json` task that runs dialyzer and outputs JSON
- Reuses dialyxir's PLT management (no reinventing wheel)
- Warning encoder converts raw dialyzer tuples to structured maps
- Supports `--quiet`, `--summary-only`, `--group-by-warning`, `--output FILE`

**Key decisions:**
- Wrap dialyxir rather than fork it (simpler maintenance)
- Call `:dialyzer.run/1` directly for raw warnings
- Use dialyxir's warning modules for friendly messages when available
- Exit code 2 when warnings exist (matches dialyxir behavior)

**Files created:**
- `lib/dialyzer_json.ex` - Main module
- `lib/dialyzer_json/warning_encoder.ex` - Warning to JSON conversion
- `lib/mix/tasks/dialyzer_json.ex` - Mix task
- `test/dialyzer_json/warning_encoder_test.exs` - Unit tests

---

## Phase 2: Warning Classification

### Task 1: Classify warning types into fix categories
**Completed** | Session 2

**What was done:**
- Created `DialyzerJson.FixHint` module to classify all 47 dialyxir warning types
- Categories: `"spec"` (11 types), `"code"` (32 types), `"pattern"` (4 types)
- Tests verify complete coverage of dialyxir's warning types

**Classification rationale:**
- `"spec"` - Contract/typespec issues where the code is correct but the @spec needs adjustment
- `"code"` - Likely real bugs requiring code changes (calls that won't succeed, impossible patterns)
- `"pattern"` - Often safe to ignore (third-party behaviour issues, intentional unused functions)

### Task 2: Add fix_hint to JSON output
**Completed** | Session 2

**What was done:**
- Added `fix_hint` field to each warning in JSON output
- Added `by_fix_hint` counts to summary statistics
- Updated documentation in moduledocs

**Files created:**
- `lib/dialyzer_json/fix_hint.ex` - Warning type classification
- `test/dialyzer_json/fix_hint_test.exs` - Classification tests
