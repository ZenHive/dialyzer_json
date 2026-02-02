# CLAUDE.md

## Project: dialyzer_json - AI-friendly JSON output for Dialyzer

### Problem

Dialyzer output is human-readable prose that's tedious for AI editors to parse. We need structured JSON output optimized for AI consumption.

### What to Build

An Elixir library that provides JSON output for dialyzer warnings, similar to how ex_unit_json provides JSON output for ExUnit tests.

### Target User

AI code editors (Claude Code, Cursor, etc.) that need to:
- Parse dialyzer warnings programmatically
- Identify patterns across warnings
- Prioritize which warnings to fix first

### Desired JSON Structure (per warning)

```json
{
  "file": "lib/foo.ex",
  "line": 42,
  "function": "bar/2",
  "module": "Foo",
  "warning_type": "no_return",
  "message": "Function has no local return",
  "fix_hint": "spec"
}
```

Where `fix_hint` is one of: `"spec"` (likely needs typespec fix), `"code"` (likely a bug), `"pattern"` (common safe-to-ignore pattern).

### Key Features (Priority Order)

1. **Basic JSON output** - Transform dialyzer warnings to JSON array
2. **Group by warning type** - `--group-by-warning` flag to cluster similar warnings
3. **Summary mode** - `--summary-only` for counts by type without details
4. **Quiet mode** - `--quiet` to suppress non-JSON output for clean piping

### Implementation Approach

Explore dialyxir's formatter system first. Options:
1. **Dialyxir formatter plugin** - If dialyxir supports pluggable formatters, create one
2. **Mix task wrapper** - `mix dialyzer.json` that calls dialyzer programmatically
3. **Post-processor** - If needed, transform `--format raw` output

Research dialyxir's codebase before deciding. Start with the simplest approach that works.

### Constraints

- This is a library, not an application
- No application config - explicit parameters only
- Follow ex_unit_json patterns where applicable
- Prefer dialyxir integration over reinventing dialyzer invocation

### Starting Point

1. Research how dialyxir formatters work (read its source)
2. Add dialyxir as dependency
3. Implement basic JSON formatter
4. Add grouping and filtering features incrementally

### Success Criteria

- `mix dialyzer.json --quiet` outputs clean JSON to stdout
- JSON is parseable and contains all warning metadata
- Grouping helps identify patterns (many warnings, few root causes)

## Commands

```bash
mix test              # Run tests
mix format            # Format code
mix dialyzer          # Run dialyzer (once implemented)
```

@include ~/.claude/includes/across-instances.md
@include ~/.claude/includes/critical-rules.md
@include ~/.claude/includes/task-prioritization.md
@include ~/.claude/includes/task-writing.md
@include ~/.claude/includes/code-style.md
@include ~/.claude/includes/development-philosophy.md
@include ~/.claude/includes/elixir-patterns.md
@include ~/.claude/includes/library-design.md
