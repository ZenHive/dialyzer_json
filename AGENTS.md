# AGENTS.md - AI Editor Guide for dialyzer_json

Quick reference for AI code editors using dialyzer_json.

## Start Here

Default workflow for analyzing dialyzer warnings:

```bash
# 1. Quick health check
mix dialyzer.json --quiet --summary-only | jq '.summary'

# 2. Find real bugs (fix_hint: "code")
mix dialyzer.json --quiet | jq '.warnings[] | select(.fix_hint == "code")'

# 3. Fix issues, then re-run to verify
mix dialyzer.json --quiet --summary-only
```

## When to Use This vs `mix dialyzer`

| Use Case | Command |
|----------|---------|
| Human reading warnings | `mix dialyzer` |
| AI parsing warnings | `mix dialyzer.json --quiet` |
| CI/CD pipelines | `mix dialyzer.json --quiet --output warnings.json` |
| Quick status check | `mix dialyzer.json --quiet --summary-only` |

## Quick Reference

```bash
# All warnings as JSON
mix dialyzer.json --quiet

# Summary only (counts, no details)
mix dialyzer.json --quiet --summary-only

# Group by warning type
mix dialyzer.json --quiet --group-by-warning

# Group by file
mix dialyzer.json --quiet --group-by-file

# Filter to specific types
mix dialyzer.json --quiet --filter-type no_return
mix dialyzer.json --quiet --filter-type no_return --filter-type call

# JSONL format (one warning per line)
mix dialyzer.json --quiet --compact

# Write to file
mix dialyzer.json --quiet --output warnings.json
```

## Key Flags

| Flag | Purpose |
|------|---------|
| `--quiet` | Suppress non-JSON output (always use for parsing) |
| `--summary-only` | Counts only, no individual warnings |
| `--group-by-warning` | Group by warning type |
| `--group-by-file` | Group by file path |
| `--filter-type TYPE` | Only show specific types (repeatable, OR logic) |
| `--compact` | JSONL output (one warning per line) |
| `--output FILE` | Write to file instead of stdout |
| `--ignore-exit-status` | Don't fail on warnings (exit 0) |

## Fix Hint Guide

The `fix_hint` field tells you what action to take:

| Hint | Meaning | Action |
|------|---------|--------|
| `"code"` | Likely a real bug | **Fix immediately** - unreachable code, impossible patterns, invalid calls |
| `"spec"` | Typespec mismatch | Fix the `@spec` - code is probably correct, spec doesn't match |
| `"pattern"` | Common safe-to-ignore | Often intentional - third-party behaviours, unused functions |
| `"unknown"` | Unrecognized warning | Investigate manually |

**Priority order:** `code` > `spec` > `pattern`

## Recommended Workflows

### Health Check

```bash
mix dialyzer.json --quiet --summary-only | jq '.summary'
```

Output:
```json
{
  "total": 5,
  "by_type": {"no_return": 2, "call": 3},
  "by_fix_hint": {"code": 4, "spec": 1}
}
```

### Find Bugs to Fix

```bash
# All code bugs
mix dialyzer.json --quiet | jq '.warnings[] | select(.fix_hint == "code")'

# Specific warning types
mix dialyzer.json --quiet --filter-type no_return --filter-type call
```

### Iterate on a Single File

```bash
mix dialyzer.json --quiet | jq '.warnings[] | select(.file == "lib/my_module.ex")'
```

### Most Common Warning Types

```bash
mix dialyzer.json --quiet | jq '.summary.by_type | to_entries | sort_by(-.value)'
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | No warnings found |
| `2` | Warnings found |
| Other | Error occurred |

Use `--ignore-exit-status` to always exit 0 (useful for CI that shouldn't fail on warnings).

## Tips

1. **Always use `--quiet`** for parsing - suppresses dialyzer progress output
2. **Pipe to jq** for filtering and formatting
3. **Use `--compact`** for large warning sets or streaming
4. **Use `--filter-type`** to focus on specific warning categories
5. **Check `fix_hint`** before fixing - `"pattern"` warnings are often intentional
6. **Use `--group-by-file`** when working through warnings file by file
