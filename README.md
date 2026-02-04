# dialyzer_json

AI-friendly JSON output for Dialyzer warnings.

Structured JSON output optimized for AI code editors (Claude Code, Cursor, etc.) that need to parse warnings programmatically.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:dialyzer_json, "~> 0.1.0", only: [:dev, :test], runtime: false}
  ]
end

def cli do
  [preferred_envs: ["dialyzer.json": :dev]]
end
```

## Quick Start

```bash
# Health check
mix dialyzer.json --quiet --summary-only | jq '.summary'

# Find real bugs
mix dialyzer.json --quiet | jq '.warnings[] | select(.fix_hint == "code")'
```

## Documentation

Full documentation at [hexdocs.pm/dialyzer_json](https://hexdocs.pm/dialyzer_json).

## License

MIT
