# AGENTS.md - AI Editor Guide

For comprehensive documentation, see:

- **llms.txt**: https://hexdocs.pm/dialyzer_json/llms.txt
- **Mix task docs**: https://hexdocs.pm/dialyzer_json/Mix.Tasks.Dialyzer.Json.html

## Quick Start

```bash
# Health check
mix dialyzer.json --quiet --summary-only | jq '.summary'

# Find real bugs
mix dialyzer.json --quiet | jq '.warnings[] | select(.fix_hint == "code")'
```
