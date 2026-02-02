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
