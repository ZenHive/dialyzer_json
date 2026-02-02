# dialyzer_json Roadmap

**Vision:** AI-friendly JSON output for Dialyzer warnings, optimized for Claude Code and similar tools.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## 🎯 Current Focus

**Phase 4: Output Enhancements** — Adding metadata, grouping options, and filtering.

### 📋 Next Up (by priority)
| Task | Priority | Description |
|------|----------|-------------|
| Task 7 | 1.3 📋 | `--group-by-file` flag |

### ✅ Recently Completed
| Task | Description | Notes |
|------|-------------|-------|
| Task 6 | `exact_compare` → `"code"` | 1-line fix |
| Task 5 | Top-level metadata | schema_version, versions, timestamp |
| Task 8 | `--compact` JSONL output | One warning per line |
| Task 9 | `--filter-type` flag | Repeatable, OR logic |
| Basic JSON output | `mix dialyzer.json` outputs warnings as JSON | Reuses dialyxir PLT |
| Quiet mode | `--quiet` suppresses non-JSON output | Clean piping to jq |
| Summary mode | `--summary-only` for counts without details | Quick health check |
| Group by warning | `--group-by-warning` clusters similar warnings | Pattern identification |
| Warning classification | All 47 warning types classified | `DialyzerJson.FixHint` module |
| fix_hint in output | Each warning has `fix_hint` field | Summary includes `by_fix_hint` |
| Tasks 3-4 | Module/function extraction for contract/callback warnings | 8 contract + 6 callback types |

---

## Phase 2: Warning Classification ✅

Added `fix_hint` field to help AI editors prioritize warnings.

- **Task 1**: Classified all 47 dialyxir warning types into `"spec"`, `"code"`, `"pattern"` categories
- **Task 2**: Added `fix_hint` to each warning and `by_fix_hint` to summary

---

## Phase 3: Better Metadata Extraction ✅

Extended module and function extraction to cover all warning types.

- **Task 3**: Module extracted from 8 contract warning types and 6 callback warning types ✅
- **Task 4**: Function extracted from contract and callback warnings (guard_fail and pattern_match don't contain function info) ✅

---

## Phase 4: Output Enhancements

### Task 5: Add top-level metadata to JSON output ✅
Add metadata fields to the root JSON object for better tooling integration.

Fields to add:
- `schema_version`: e.g. "1.0" (for future compatibility)
- `dialyzer_version`: from `:dialyzer` app version
- `elixir_version`: from `System.version()`
- `otp_version`: from `:erlang.system_info(:otp_release)`
- `run_at`: ISO8601 timestamp (optional, include by default)

Success criteria:
- [x] All version fields present in output
- [x] `run_at` is valid ISO8601 format
- [x] Existing `warnings` and `summary` structure unchanged

### Task 6: Extend fix_hint mapping for exact_compare ✅
Map `exact_compare` warning type to `"code"` (currently falls through to unknown). These are actionable warnings about `==` vs `===` comparisons.

Success criteria:
- [x] `exact_compare` → `"code"` in FixHint module
- [x] Test covers the mapping

### Task 7: Add --group-by-file flag [D:3/B:4 → Priority:1.3] 📋
Add `--group-by-file` flag to group warnings by file path instead of warning type.

Output format:
```json
{
  "groups": [
    { "file": "lib/foo.ex", "count": 3, "warnings": [...] }
  ],
  "summary": { ... }
}
```

Success criteria:
- [ ] `--group-by-file` groups warnings by file
- [ ] Each group has `file`, `count`, and `warnings` fields
- [ ] Default output (flat warnings) unchanged

### Task 8: Add --compact flag for JSONL output ✅
Add `--compact` flag that outputs one JSON object per line (JSONL format) instead of a single JSON array. Useful for streaming large warning sets.

Success criteria:
- [x] `--compact` outputs one warning per line
- [x] Each line is valid JSON
- [x] Summary on final line in compact mode

### Task 9: Add --filter-type flag ✅
Add `--filter-type TYPE` flag to output only warnings of a specific type. Can be repeated for multiple types.

Success criteria:
- [x] `--filter-type no_return` shows only no_return warnings
- [x] Multiple `--filter-type` flags combine with OR logic
- [x] Summary reflects filtered count

---

## Phase 5: Documentation & Polish [D:2/B:5 → Priority:2.5] 🎯

### Task 10: Add hex.pm package metadata [D:2/B:6 → Priority:3.0] 🎯
Prepare for hex.pm publication. Add package metadata, description, links, and licenses to mix.exs.

Success criteria:
- [ ] `mix hex.build` succeeds
- [ ] Package description is clear and useful
- [ ] GitHub link included

### Task 11: Write usage examples for AI editors [D:2/B:4 → Priority:2.0] 🎯
Add examples to README showing how AI editors can use the JSON output. Include jq patterns for common queries.

Success criteria:
- [ ] README has "For AI Editors" section
- [ ] jq examples for filtering by type, file, etc.
- [ ] Example integration with Claude Code
