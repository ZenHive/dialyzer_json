# dialyzer_json Roadmap

**Vision:** AI-friendly JSON output for Dialyzer warnings, optimized for Claude Code and similar tools.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## 🎯 Current Focus

**Phase 1: Core Foundation** — Complete. Basic JSON output working.

### ✅ Recently Completed
| Task | Description | Notes |
|------|-------------|-------|
| Basic JSON output | `mix dialyzer.json` outputs warnings as JSON | Reuses dialyxir PLT |
| Quiet mode | `--quiet` suppresses non-JSON output | Clean piping to jq |
| Summary mode | `--summary-only` for counts without details | Quick health check |
| Group by warning | `--group-by-warning` clusters similar warnings | Pattern identification |

---

## Phase 2: Warning Classification [D:5/B:8 → Priority:1.6] 🚀

Add `fix_hint` field to help AI editors prioritize which warnings to fix first.

### Task 1: Classify warning types into fix categories [D:4/B:8 → Priority:2.0] 🎯
Research dialyzer's ~47 warning types and classify each into one of three categories:
- `"spec"` - Likely needs typespec fix (contract issues, return type mismatches)
- `"code"` - Likely a real bug (unreachable code, pattern match failures)
- `"pattern"` - Common safe-to-ignore pattern (callback info missing, etc.)

Output a mapping module that returns the category for each warning type. Include rationale comments for non-obvious classifications.

Success criteria:
- [ ] All warning types from `Dialyxir.Warnings` are classified
- [ ] Classification logic is in a dedicated module
- [ ] Tests verify classification for representative warning types

### Task 2: Add fix_hint to JSON output [D:2/B:7 → Priority:3.5] 🎯
Add `fix_hint` field to each warning in the JSON output using the classification from Task 1. Include in summary stats (counts by fix_hint type).

Success criteria:
- [ ] Each warning object has `fix_hint` field
- [ ] Summary includes `by_fix_hint` counts
- [ ] Tests verify fix_hint appears in output

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
