defmodule DialyzerJson do
  @moduledoc """
  AI-friendly JSON output for Dialyzer warnings.

  Provides structured JSON output for dialyzer warnings optimized for AI code editors
  (Claude Code, Cursor, etc.) that need to parse warnings programmatically.

  ## Usage

      mix dialyzer.json              # JSON output to stdout
      mix dialyzer.json --quiet      # Suppress non-JSON output for clean piping
      mix dialyzer.json --summary-only   # Counts by type without details

  ## JSON Structure

  Each warning is output as:

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

  The `fix_hint` field indicates the likely fix category:
  - `"spec"` - Likely needs typespec fix
  - `"code"` - Likely a real bug
  - `"pattern"` - Common safe-to-ignore pattern
  - `"unknown"` - Unrecognized warning type
  """
end
