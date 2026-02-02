# dialyzer_json

AI-friendly JSON output for Dialyzer warnings.

Dialyzer's default output is human-readable prose that's tedious for AI editors to parse. This library provides structured JSON output optimized for AI code editors (Claude Code, Cursor, etc.) that need to parse warnings programmatically.

## Installation

Add `dialyzer_json` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dialyzer_json, "~> 0.1.0", only: [:dev, :test], runtime: false}
  ]
end
```

**As a path dependency** (for development or unpublished use):

```elixir
def deps do
  [
    {:dialyzer_json, path: "../dialyzer_json", only: [:dev, :test], runtime: false}
  ]
end
```

Then add the CLI configuration to enable the mix task:

```elixir
def cli do
  [preferred_envs: ["dialyzer.json": :dev]]
end
```

## Usage

```bash
# Basic JSON output
mix dialyzer.json

# Quiet mode - suppress non-JSON output for clean piping
mix dialyzer.json --quiet

# Summary only - counts by type without individual warnings
mix dialyzer.json --summary-only

# Group warnings by type
mix dialyzer.json --group-by-warning

# Write to file
mix dialyzer.json --output warnings.json

# Ignore exit status (don't fail on warnings)
mix dialyzer.json --ignore-exit-status

# Compact JSONL output (one warning per line)
mix dialyzer.json --compact

# Filter by warning type (repeatable)
mix dialyzer.json --filter-type no_return
mix dialyzer.json --filter-type no_return --filter-type call
```

## Output Format

Each warning includes:

```json
{
  "file": "lib/foo.ex",
  "line": 42,
  "column": 5,
  "function": "bar/2",
  "module": "Foo",
  "warning_type": "no_return",
  "message": "Function has no local return",
  "raw_message": "Function bar/2 has no local return.",
  "fix_hint": "code"
}
```

**Note:** The `module` and `function` fields are extracted when available in the warning args:
- For contract warnings (`contract_diff`, `extra_range`, etc.), both module and function are extracted
- For callback warnings (`callback_type_mismatch`, etc.), `module` contains the behaviour (e.g., `GenServer`)
- For some warnings (`pattern_match`, `guard_fail`), these fields may be `null` as the info isn't in the warning args

The `fix_hint` field helps prioritize which warnings to fix:

| Hint | Meaning | Action |
|------|---------|--------|
| `"code"` | Likely a real bug | Fix the code - unreachable code, impossible patterns, invalid calls |
| `"spec"` | Typespec mismatch | Fix the `@spec` - code is probably correct, but spec doesn't match |
| `"pattern"` | Common safe-to-ignore | Often intentional - third-party behaviours, unused functions |
| `"unknown"` | Unrecognized warning | Investigate manually |

Full output includes metadata and summary:

```json
{
  "metadata": {
    "schema_version": "1.0",
    "dialyzer_version": "5.4",
    "elixir_version": "1.19.4",
    "otp_version": "28",
    "run_at": "2026-02-02T07:00:03.768447Z"
  },
  "warnings": [...],
  "summary": {
    "total": 5,
    "by_type": {"no_return": 2, "call": 3},
    "by_fix_hint": {"code": 4, "spec": 1}
  }
}
```

## For AI Editors

### Quick Health Check

```bash
mix dialyzer.json --quiet --summary-only | jq '.summary'
```

### Find All Code Bugs

```bash
mix dialyzer.json --quiet | jq '.warnings[] | select(.fix_hint == "code")'
```

### Warnings by File

```bash
mix dialyzer.json --quiet | jq 'group_by(.file) | map({file: .[0].file, count: length})'
```

### Most Common Warning Types

```bash
mix dialyzer.json --quiet | jq '.summary.by_type | to_entries | sort_by(-.value)'
```

### Warnings in a Specific File

```bash
mix dialyzer.json --quiet | jq '.warnings[] | select(.file == "lib/my_module.ex")'
```

### Filter by Warning Type (no jq needed)

```bash
# Only no_return warnings
mix dialyzer.json --quiet --filter-type no_return

# Multiple types (OR logic)
mix dialyzer.json --quiet --filter-type no_return --filter-type call
```

### Compact JSONL Output (for streaming/large sets)

```bash
# One warning per line - great for wc, grep, head, tail
mix dialyzer.json --quiet --compact | wc -l

# Process line by line
mix dialyzer.json --quiet --compact | while read line; do echo "$line" | jq '.file'; done
```

### Exit Codes

- `0` - No warnings found
- `2` - Warnings found (allows scripts to detect warnings programmatically)
- Non-zero - Error occurred

## Integration with Claude Code

Add to your project's `CLAUDE.md`:

```markdown
## Dialyzer

Run `mix dialyzer.json --quiet` for JSON output suitable for parsing.
Use `--summary-only` for a quick health check.

Fix hints:
- `code` = real bugs, fix immediately
- `spec` = typespec issues, fix the @spec
- `pattern` = usually safe to ignore
```

## License

MIT
