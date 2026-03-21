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
- `--output FILE` - Write JSON to file instead of stdout
- `--ignore-exit-status` - Always exit 0 (useful for CI)

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
- **Runtime `apply/3` for dialyxir calls** — `run_dialyzer/0` and `get_dialyxir_warning_module/1` use `apply(Dialyxir.Project, ...)` and `apply(Dialyxir.Warnings, ...)` with `credo:disable` comments. This avoids compile-time warnings when consumers use this as a path dependency. Do not refactor these to direct calls.
- **Leverages dialyxir's warning modules** for friendly `message` field when available, falls back to raw dialyzer formatting
- **Module/function extraction** varies by warning type (contract warnings have MFA pattern, callback warnings have BFA pattern)
- **Exit codes**: 0 = no warnings, 2 = warnings found. In `--quiet` mode, uses `System.halt/1` for silent exit; otherwise raises via `Mix.raise/1`
- **Stdout buffering in quiet mode**: When `--quiet` is used without `--output`, JSON is buffered to a temp file and written after dialyzer finishes, preventing stdout pollution from corrupting JSON output

### Testing Conventions

Tests construct raw dialyzer warning tuples directly rather than running dialyzer. The tuple format is `{tag, {file, location}, {warning_type, args}}` where:
- `tag` is an atom like `:warn_return_no_exit`, `:warn_contract`, `:warn_callback`, `:warn_failing_call`
- `file` is a charlist (`~c"lib/foo.ex"`) or binary
- `location` is a line number or `{line, column}` tuple
- `args` structure varies by `warning_type` — check existing tests for patterns

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

@~/.claude/includes/across-instances.md
@~/.claude/includes/critical-rules.md
@~/.claude/includes/task-prioritization.md
@~/.claude/includes/task-writing.md
@~/.claude/includes/web-command.md
@~/.claude/includes/code-style.md
@~/.claude/includes/development-philosophy.md
@~/.claude/includes/documentation-guidelines.md
@~/.claude/includes/agent-economy.md
@~/.claude/includes/elixir-patterns.md
@~/.claude/includes/elixir-setup.md
@~/.claude/includes/development-commands.md
@~/.claude/includes/ex-unit-json.md
@~/.claude/includes/dialyzer-json.md
@~/.claude/includes/library-design.md

## Git Commit Configuration

**Configured**: 2026-02-02

### Commit Message Format

**Format**: conventional-commits

#### Conventional Commits Template
```
<type>(<scope>): <description>
```
**Types**: feat, fix, docs, style, refactor, test, chore
