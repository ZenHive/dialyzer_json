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

---

## Phase 3: Better Metadata Extraction

### Tasks 3-4: Extract module and function for all warning types
**Completed** | Session 3

**What was done:**
- Extended `extract_module/2` to handle contract and callback warnings
- Extended `extract_function/2` to handle contract and callback warnings
- Added 11 new test cases for comprehensive coverage

**Warning patterns now supported:**

| Pattern | Warning Types | Module Source | Function Source |
|---------|---------------|---------------|-----------------|
| `[module, function, arity, ...]` | contract_diff, contract_subtype, contract_supertype, contract_with_opaque, extra_range, invalid_contract, missing_range, overlapping_contract | args[0] | args[1]/args[2] |
| `[contract, module, function, arg_strings, ...]` | contract_range | args[1] | args[2]/length(args[3]) |
| `[behaviour, function, arity, ...]` | callback_type_mismatch, callback_arg_type_mismatch, callback_missing, callback_not_exported, callback_spec_type_mismatch, callback_spec_arg_type_mismatch | args[0] (behaviour) | args[1]/args[2] |

**Key decisions:**
- For callback warnings, `module` field contains the behaviour module (e.g., `GenServer`) since that's the relevant context
- Added `format_module/1` helper to handle both atom and charlist module names
- Used module attributes (`@contract_mfa_warnings`, `@callback_bfa_warnings`) to group similar patterns

---

## Phase 4: Output Enhancements

### Tasks 8-9: CLI Enhancements (--compact and --filter-type)
**Completed** | Session 4

**What was done:**
- Added `--compact` flag for JSONL output (one JSON object per line)
- Added `--filter-type TYPE` flag to filter warnings by type (repeatable, OR logic)
- Summary reflects filtered count when using `--filter-type`
- Compact mode works with all other flags (`--summary-only`, `--group-by-warning`, `--filter-type`)

**Flag interactions:**
| Combination | Behavior |
|-------------|----------|
| `--compact` | JSONL: warnings + summary line |
| `--compact --summary-only` | Summary line only |
| `--compact --group-by-warning` | Warnings flattened to JSONL |
| `--filter-type X` | Only X warnings |
| `--filter-type X --filter-type Y` | X or Y (OR logic) |

**Files modified:**
- `lib/mix/tasks/dialyzer_json.ex` - Added parsing, filtering, JSONL formatting
- `test/mix/tasks/dialyzer_json_test.exs` - 13 new tests for both flags

### Tasks 5-6: Metadata and exact_compare fix
**Completed** | Session 5

**What was done:**
- Added top-level `metadata` field to all JSON output
- Added `exact_compare` warning type to `"code"` classification

**Metadata fields:**
| Field | Source |
|-------|--------|
| `schema_version` | `"1.0"` (for future compatibility) |
| `dialyzer_version` | `:dialyzer` app version |
| `elixir_version` | `System.version()` |
| `otp_version` | `:erlang.system_info(:otp_release)` |
| `run_at` | ISO8601 timestamp |

**Output structure now:**
```json
{
  "metadata": { ... },
  "warnings": [...],
  "summary": { ... }
}
```

**Compact mode:** Metadata included on the final summary line.

**Files modified:**
- `lib/mix/tasks/dialyzer_json.ex` - Added `build_metadata/0`, updated `encode_output/2` and `build_compact_output/1`
- `lib/dialyzer_json/fix_hint.ex` - Added `:exact_compare` to `@code_warnings`
- `test/mix/tasks/dialyzer_json_test.exs` - Added metadata tests
- `test/dialyzer_json/fix_hint_test.exs` - Added `:exact_compare` to test list
