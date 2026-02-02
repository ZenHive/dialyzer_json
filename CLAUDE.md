# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: dialyzer_json - AI-friendly JSON output for Dialyzer

**Published:** [hex.pm/packages/dialyzer_json](https://hex.pm/packages/dialyzer_json) | [hexdocs.pm/dialyzer_json](https://hexdocs.pm/dialyzer_json)

### What It Does

Provides JSON output for Dialyzer warnings, optimized for AI code editors (Claude Code, Cursor, etc.) that need to:
- Parse dialyzer warnings programmatically
- Identify patterns across warnings
- Prioritize which warnings to fix first

### JSON Structure (per warning)

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

### Key Features

- `--quiet` - Suppress non-JSON output for clean piping
- `--summary-only` - Counts by type without individual warnings
- `--group-by-warning` - Cluster warnings by type
- `--group-by-file` - Cluster warnings by file
- `--filter-type TYPE` - Filter to specific warning types (repeatable)
- `--compact` - JSONL output (one warning per line)

## Commands

```bash
mix test                        # Run tests
mix test path/to/test.exs:42    # Run single test at line
mix format                      # Format code
mix dialyzer.json               # Run dialyzer with JSON output
```

## Architecture

The codebase has 3 modules with clear responsibilities:

```
lib/
├── dialyzer_json.ex           # Root module (moduledoc only, no code)
├── dialyzer_json/
│   ├── warning_encoder.ex     # Converts raw dialyzer tuples → JSON maps
│   └── fix_hint.ex            # Classifies warning types → fix categories
└── mix/tasks/
    └── dialyzer_json.ex       # Mix task: CLI parsing, dialyzer invocation, output
```

### Data Flow

1. **Mix.Tasks.Dialyzer.Json** runs dialyzer via `:dialyzer.run/1` and gets raw warnings
2. **WarningEncoder** transforms `{tag, {file, location}, {warning_type, args}}` tuples into maps
3. **FixHint** classifies each `warning_type` atom into `"spec"`, `"code"`, `"pattern"`, or `"unknown"`
4. Task handles filtering, grouping, and JSON output

### Key Design Decisions

- **Uses dialyxir's PLT/files** but calls `:dialyzer.run/1` directly for raw warnings
- **Runtime checks for dialyxir modules** (`Code.ensure_loaded?/1`) to avoid compile-time warnings when used as path dependency
- **Leverages dialyxir's warning modules** for friendly `message` field when available, falls back to raw dialyzer formatting
- **Module/function extraction** varies by warning type (contract warnings have MFA pattern, callback warnings have BFA pattern)

## Installation

### From hex.pm (recommended)

```elixir
{:dialyzer_json, "~> 0.1", only: [:dev, :test], runtime: false}
```

### From local path (development)

```elixir
{:dialyzer_json, path: "../dialyzer_json", only: [:dev, :test], runtime: false}
```

## Private Function Documentation

Private functions (`defp`) must have `@doc false` and a comment explaining their purpose:

```elixir
# ✅ Correct: @doc false + explanatory comment
@doc false
# Normalizes the input map by converting string keys to atoms
defp normalize_input(map) do
  Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
end

# ✅ Correct: trivial one-liners can skip the comment
@doc false
defp add(a, b), do: a + b

# ❌ Wrong: missing @doc false and comment
defp normalize_input(map) do
  Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
end
```

**Why `@doc false`?** Explicitly marks the function as intentionally undocumented (not forgotten). ExDoc won't generate docs for it.

**Why a comment?** Future readers (including Claude) understand the function's purpose without reading the implementation.

**Exception:** Trivial one-liner helpers don't need comments - the code is self-documenting.

@include ~/.claude/includes/across-instances.md
@include ~/.claude/includes/critical-rules.md
@include ~/.claude/includes/task-prioritization.md
@include ~/.claude/includes/task-writing.md
@include ~/.claude/includes/code-style.md
@include ~/.claude/includes/development-philosophy.md
@include ~/.claude/includes/elixir-patterns.md
@include ~/.claude/includes/library-design.md

## Git Commit Configuration

**Configured**: 2026-02-02

### Commit Message Format

**Format**: conventional-commits

#### Conventional Commits Template
```
<type>(<scope>): <description>
```
**Types**: feat, fix, docs, style, refactor, test, chore
