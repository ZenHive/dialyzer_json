# dialyzer_json Roadmap

**Vision:** AI-friendly JSON output for Dialyzer warnings, optimized for Claude Code and similar tools.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## 🎯 Current Focus

**Phase 2: Warning Classification** — Complete. `fix_hint` field added to all warnings.

### ✅ Recently Completed
| Task | Description | Notes |
|------|-------------|-------|
| Basic JSON output | `mix dialyzer.json` outputs warnings as JSON | Reuses dialyxir PLT |
| Quiet mode | `--quiet` suppresses non-JSON output | Clean piping to jq |
| Summary mode | `--summary-only` for counts without details | Quick health check |
| Group by warning | `--group-by-warning` clusters similar warnings | Pattern identification |
| Warning classification | All 47 warning types classified | `DialyzerJson.FixHint` module |
| fix_hint in output | Each warning has `fix_hint` field | Summary includes `by_fix_hint` |

---

## Phase 2: Warning Classification ✅

Added `fix_hint` field to help AI editors prioritize warnings.

- **Task 1**: Classified all 47 dialyxir warning types into `"spec"`, `"code"`, `"pattern"` categories
- **Task 2**: Added `fix_hint` to each warning and `by_fix_hint` to summary

---

## Phase 3: Better Metadata Extraction [D:6/B:6 → Priority:1.0] 📋

Extract more structured data from warning arguments.

### Task 3: Extract module for all warning types [D:5/B:5 → Priority:1.0] 📋
Currently module extraction only works for `:call` warnings. Extend to extract module from all warning types where applicable (callback warnings, contract warnings, etc.).

Success criteria:
- [ ] Module extracted from callback_* warnings
- [ ] Module extracted from contract_* warnings
- [ ] Tests for each warning type with module info

### Task 4: Extract function for all warning types [D:5/B:5 → Priority:1.0] 📋
Currently function extraction only works for `:no_return` and `:call`. Extend to all warning types that reference functions.

Success criteria:
- [ ] Function extracted from guard_fail warnings
- [ ] Function extracted from pattern_match warnings
- [ ] Tests for each warning type with function info

---

## Phase 4: Output Enhancements [D:3/B:4 → Priority:1.3] 📋

### Task 5: Add --compact flag for JSONL output [D:3/B:4 → Priority:1.3] 📋
Add `--compact` flag that outputs one JSON object per line (JSONL format) instead of a single JSON array. Useful for streaming large warning sets.

Success criteria:
- [ ] `--compact` outputs one warning per line
- [ ] Each line is valid JSON
- [ ] No trailing summary in compact mode (or separate line)

### Task 6: Add --filter-type flag [D:2/B:3 → Priority:1.5] 🚀
Add `--filter-type TYPE` flag to output only warnings of a specific type. Can be repeated for multiple types.

Success criteria:
- [ ] `--filter-type no_return` shows only no_return warnings
- [ ] Multiple `--filter-type` flags combine with OR logic
- [ ] Summary reflects filtered count

---

## Phase 5: Documentation & Polish [D:2/B:5 → Priority:2.5] 🎯

### Task 7: Add hex.pm package metadata [D:2/B:6 → Priority:3.0] 🎯
Prepare for hex.pm publication. Add package metadata, description, links, and licenses to mix.exs.

Success criteria:
- [ ] `mix hex.build` succeeds
- [ ] Package description is clear and useful
- [ ] GitHub link included

### Task 8: Write usage examples for AI editors [D:2/B:4 → Priority:2.0] 🎯
Add examples to README showing how AI editors can use the JSON output. Include jq patterns for common queries.

Success criteria:
- [ ] README has "For AI Editors" section
- [ ] jq examples for filtering by type, file, etc.
- [ ] Example integration with Claude Code
