defmodule Mix.Tasks.Dialyzer.Json do
  @shortdoc "Run dialyzer with JSON output"

  @moduledoc """
  Runs dialyzer and outputs warnings as JSON.

  This task wraps dialyxir's PLT building but calls `:dialyzer.run/1` directly,
  transforming raw warnings to structured JSON optimized for AI code editors
  (Claude Code, Cursor, etc.).

  ## Quick Start

      # Health check - see summary counts
      mix dialyzer.json --quiet --summary-only | jq '.summary'

      # Find real bugs (fix_hint: "code")
      mix dialyzer.json --quiet | jq '.warnings[] | select(.fix_hint == "code")'

      # Fix issues, then re-run to verify
      mix dialyzer.json --quiet --summary-only

  ## When to Use This vs `mix dialyzer`

  | Use Case | Command |
  |----------|---------|
  | Human reading warnings | `mix dialyzer` |
  | AI parsing warnings | `mix dialyzer.json --quiet` |
  | CI/CD pipelines | `mix dialyzer.json --quiet --output warnings.json` |
  | Quick status check | `mix dialyzer.json --quiet --summary-only` |

  ## Options

    * `--quiet` - Suppress non-JSON output (always use for parsing)
    * `--summary-only` - Counts only, no individual warnings
    * `--group-by-warning` - Group warnings by type
    * `--group-by-file` - Group warnings by file path
    * `--filter-type TYPE` - Only show specific types (repeatable, OR logic)
    * `--compact` - JSONL output (one warning per line)
    * `--output FILE` - Write to file instead of stdout
    * `--ignore-exit-status` - Don't fail on warnings (exit 0)

  ## Output Format

  Full output includes metadata and summary:

      {
        "metadata": {
          "schema_version": "1.0",
          "dialyzer_version": "5.4",
          "elixir_version": "1.19.4",
          "otp_version": "28",
          "run_at": "2026-02-02T07:00:03Z"
        },
        "warnings": [...],
        "summary": {
          "total": 5,
          "skipped": 0,
          "by_type": {"no_return": 2, "call": 3},
          "by_fix_hint": {"code": 4, "spec": 1}
        }
      }

  Each warning object contains:

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

  With `--group-by-warning`, warnings are grouped by type:

      {"warnings": {"no_return": [...], "call": [...]}, ...}

  With `--group-by-file`, warnings are grouped by file:

      {"groups": [{"file": "lib/foo.ex", "count": 3, "warnings": [...]}], ...}

  ## Fix Hint Guide

  The `fix_hint` field tells you what action to take:

  | Hint | Meaning | Action |
  |------|---------|--------|
  | `"code"` | Likely a real bug | **Fix immediately** - unreachable code, impossible patterns |
  | `"spec"` | Typespec mismatch | Fix the `@spec` - code is probably correct |
  | `"pattern"` | Common safe-to-ignore | Often intentional - third-party behaviours |
  | `"unknown"` | Unrecognized warning | Investigate manually |

  **Priority order:** `code` > `spec` > `pattern`

  ## Common jq Recipes

      # Find all code bugs
      mix dialyzer.json --quiet | jq '.warnings[] | select(.fix_hint == "code")'

      # Most common warning types
      mix dialyzer.json --quiet | jq '.summary.by_type | to_entries | sort_by(-.value)'

      # Warnings in a specific file
      mix dialyzer.json --quiet | jq '.warnings[] | select(.file == "lib/my_module.ex")'

      # Count warnings per file
      mix dialyzer.json --quiet | jq '.warnings | group_by(.file) | map({file: .[0].file, count: length})'

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
  """

  use Mix.Task

  alias DialyzerJson.WarningEncoder

  # Exit code when dialyzer finds warnings (standard convention: 2 = warnings found)
  @exit_code_warnings_found 2

  @impl Mix.Task
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {opts, _remaining} = extract_opts(args)

    # Suppress output immediately when --quiet is used
    # Must happen BEFORE compile/dialyzer tasks run
    if opts[:quiet] do
      Mix.shell(Mix.Shell.Quiet)
      :logger.remove_handler(:default)
      Application.put_env(:logger, :level, :error)
    end

    # When --quiet without --output, buffer to temp file for clean piping
    {opts, temp_output_path} = maybe_use_temp_output(opts)

    # Ensure dialyxir's PLT is ready
    ensure_plt!()

    # Run dialyzer and get warnings
    raw_warnings = run_dialyzer()

    # Filter ignored warnings (.dialyzer_ignore.exs)
    filter_map = load_filter_map()
    {warnings, skipped} = apply_ignore_filter(raw_warnings, filter_map)

    # Encode to JSON
    encoded = encode_output(warnings, Keyword.put(opts, :skipped, skipped))

    # Output
    output_json(encoded, opts)

    # If we used temp buffering, output JSON now (after all other stdout pollution)
    if temp_output_path do
      output_buffered_json(temp_output_path)
    end

    # Exit with appropriate code
    cond do
      warnings == [] or opts[:ignore_exit_status] ->
        :ok

      opts[:quiet] ->
        # In quiet mode, exit silently - the exit code indicates failure
        System.halt(@exit_code_warnings_found)

      true ->
        Mix.raise("Dialyzer found #{length(warnings)} warning(s)")
    end
  end

  @doc false
  # Parses command-line arguments into options keyword list
  @spec extract_opts([String.t()]) :: {keyword(), [String.t()]}
  def extract_opts(args) do
    {opts, remaining} = do_extract_opts(args, [], [])
    {merge_list_opts(opts), remaining}
  end

  defp do_extract_opts([], opts, remaining) do
    {Enum.reverse(opts), Enum.reverse(remaining)}
  end

  defp do_extract_opts(["--quiet" | rest], opts, remaining) do
    do_extract_opts(rest, [{:quiet, true} | opts], remaining)
  end

  defp do_extract_opts(["--summary-only" | rest], opts, remaining) do
    do_extract_opts(rest, [{:summary_only, true} | opts], remaining)
  end

  defp do_extract_opts(["--group-by-warning" | rest], opts, remaining) do
    do_extract_opts(rest, [{:group_by_warning, true} | opts], remaining)
  end

  defp do_extract_opts(["--group-by-file" | rest], opts, remaining) do
    do_extract_opts(rest, [{:group_by_file, true} | opts], remaining)
  end

  defp do_extract_opts(["--output", path | rest], opts, remaining) do
    do_extract_opts(rest, [{:output, path} | opts], remaining)
  end

  defp do_extract_opts(["--ignore-exit-status" | rest], opts, remaining) do
    do_extract_opts(rest, [{:ignore_exit_status, true} | opts], remaining)
  end

  defp do_extract_opts(["--compact" | rest], opts, remaining) do
    do_extract_opts(rest, [{:compact, true} | opts], remaining)
  end

  defp do_extract_opts(["--filter-type", type | rest], opts, remaining) do
    do_extract_opts(rest, [{:filter_type, type} | opts], remaining)
  end

  defp do_extract_opts([arg | rest], opts, remaining) do
    do_extract_opts(rest, opts, [arg | remaining])
  end

  @doc false
  # Collects repeated CLI options (like multiple --filter-type flags) into a single list value.
  # E.g., [{:filter_type, "a"}, {:filter_type, "b"}] -> [{:filter_type, ["a", "b"]}]
  @spec merge_list_opts(keyword()) :: keyword()
  defp merge_list_opts(opts) do
    {filter_types, other_opts} = Keyword.pop_values(opts, :filter_type)

    if filter_types == [] do
      other_opts
    else
      [{:filter_type, filter_types} | other_opts]
    end
  end

  @doc false
  # Ensures dialyxir's PLT is built and up to date
  @spec ensure_plt!() :: :ok
  defp ensure_plt! do
    Mix.Task.run("compile")
    Mix.Task.run("dialyzer", ["--plt"])
    :ok
  end

  @doc false
  # Filters raw warnings against the project's ignore file (.dialyzer_ignore.exs).
  # Returns {kept_warnings, skipped_count}.
  @spec apply_ignore_filter([WarningEncoder.warning()], struct()) ::
          {[WarningEncoder.warning()], non_neg_integer()}
  def apply_ignore_filter(warnings, filter_map) do
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    if apply(Dialyxir.FilterMap, :filters, [filter_map]) == [] do
      {warnings, 0}
    else
      {kept, skipped} =
        Enum.reduce(warnings, {[], 0}, &partition_warning(&1, &2, filter_map))

      {Enum.reverse(kept), skipped}
    end
  end

  @doc false
  # Checks a single warning against the filter map and partitions into kept/skipped
  @spec partition_warning(
          WarningEncoder.warning(),
          {[WarningEncoder.warning()], non_neg_integer()},
          struct()
        ) ::
          {[WarningEncoder.warning()], non_neg_integer()}
  defp partition_warning(warning, {kept_acc, skipped_acc}, filter_map) do
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    {should_skip, _matching} = apply(Dialyxir.Project, :filter_warning?, [warning, filter_map])

    if should_skip do
      {kept_acc, skipped_acc + 1}
    else
      {[warning | kept_acc], skipped_acc}
    end
  end

  @doc false
  # Loads the FilterMap from the project's ignore_warnings config
  @spec load_filter_map() :: struct()
  defp load_filter_map do
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    apply(Dialyxir.Project, :filter_map, [[]])
  end

  @doc false
  # Computes warning flags matching dialyxir's logic:
  # transform(raw_opts) ++ (@default_warnings -- removed_defaults)
  @spec build_warning_flags([atom()], [atom()]) :: [atom()]
  def build_warning_flags(flags, removed_defaults) do
    flags ++ ([:unknown] -- removed_defaults)
  end

  @doc false
  # Runs dialyzer and returns the list of warnings
  @spec run_dialyzer() :: [WarningEncoder.warning()]
  defp run_dialyzer do
    # Runtime calls to avoid compile-time warnings when used as a path dependency
    # credo:disable-for-lines:4 Credo.Check.Refactor.Apply
    plt_file = apply(Dialyxir.Project, :plt_file, [])
    files = apply(Dialyxir.Project, :dialyzer_files, [])
    flags = apply(Dialyxir.Project, :dialyzer_flags, [])
    removed_defaults = apply(Dialyxir.Project, :dialyzer_removed_defaults, [])

    warnings = build_warning_flags(flags, removed_defaults)

    args = [
      check_plt: false,
      init_plt: String.to_charlist(plt_file),
      files: files,
      warnings: warnings
    ]

    try do
      :dialyzer.run(args)
    catch
      {:dialyzer_error, msg} ->
        Mix.shell().error("Dialyzer error: #{msg}")
        []
    end
  end

  @doc false
  # Transforms raw warnings into JSON-ready output structure based on options
  @spec encode_output([WarningEncoder.warning()], keyword()) :: map()
  def encode_output(warnings, opts) do
    encoded_warnings =
      warnings
      |> WarningEncoder.encode_warnings()
      |> filter_warnings(opts[:filter_type])

    summary = %{
      total: length(encoded_warnings),
      skipped: Keyword.get(opts, :skipped, 0),
      by_type: count_by_type(encoded_warnings),
      by_fix_hint: count_by_fix_hint(encoded_warnings)
    }

    metadata = build_metadata()

    if opts[:summary_only] do
      %{metadata: metadata, summary: summary}
    else
      cond do
        opts[:group_by_file] ->
          %{
            metadata: metadata,
            groups: group_by_file(encoded_warnings),
            summary: summary
          }

        opts[:group_by_warning] ->
          %{
            metadata: metadata,
            warnings: group_by_type(encoded_warnings),
            summary: summary
          }

        true ->
          %{
            metadata: metadata,
            warnings: encoded_warnings,
            summary: summary
          }
      end
    end
  end

  @doc false
  # Filters warnings to only include specified types
  @spec filter_warnings([WarningEncoder.encoded_warning()], [String.t()] | nil) ::
          [WarningEncoder.encoded_warning()]
  def filter_warnings(warnings, nil), do: warnings
  def filter_warnings(warnings, []), do: warnings

  def filter_warnings(warnings, types) when is_list(types) do
    Enum.filter(warnings, &(&1.warning_type in types))
  end

  @doc false
  # Counts warnings grouped by warning type
  @spec count_by_type([WarningEncoder.encoded_warning()]) :: %{String.t() => non_neg_integer()}
  def count_by_type(warnings) do
    Enum.reduce(warnings, %{}, fn warning, acc ->
      Map.update(acc, warning.warning_type, 1, &(&1 + 1))
    end)
  end

  @doc false
  # Counts warnings grouped by fix hint category
  @spec count_by_fix_hint([WarningEncoder.encoded_warning()]) :: %{
          String.t() => non_neg_integer()
        }
  def count_by_fix_hint(warnings) do
    Enum.reduce(warnings, %{}, fn warning, acc ->
      Map.update(acc, warning.fix_hint, 1, &(&1 + 1))
    end)
  end

  @doc false
  # Groups warnings by warning type into a map
  @spec group_by_type([WarningEncoder.encoded_warning()]) :: %{
          String.t() => [WarningEncoder.encoded_warning()]
        }
  def group_by_type(warnings) do
    Enum.group_by(warnings, & &1.warning_type)
  end

  @doc false
  # Groups warnings by file path into an array of objects with file, count, and warnings fields
  @spec group_by_file([WarningEncoder.encoded_warning()]) :: [
          %{
            file: String.t(),
            count: non_neg_integer(),
            warnings: [WarningEncoder.encoded_warning()]
          }
        ]
  def group_by_file(warnings) do
    warnings
    |> Enum.group_by(& &1.file)
    |> Enum.map(fn {file, file_warnings} ->
      %{file: file, count: length(file_warnings), warnings: file_warnings}
    end)
    |> Enum.sort_by(& &1.file)
  end

  @doc false
  # Builds metadata with version info and timestamp
  @spec build_metadata() :: map()
  def build_metadata do
    %{
      schema_version: "1.0",
      dialyzer_version: to_string(Application.spec(:dialyzer, :vsn)),
      elixir_version: System.version(),
      otp_version: to_string(:erlang.system_info(:otp_release)),
      run_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc false
  # Outputs JSON to stdout or file based on options
  @spec output_json(map(), keyword()) :: :ok
  defp output_json(data, opts) do
    output =
      if opts[:compact] do
        build_compact_output(data)
      else
        Jason.encode!(data, pretty: true)
      end

    case opts[:output] do
      nil -> IO.puts(output)
      path -> File.write!(path, output <> "\n")
    end

    :ok
  end

  @doc false
  # Builds JSONL output (one JSON object per line) for streaming/piping.
  # Each warning becomes a single JSON line, with metadata and summary as the final line.
  @spec build_compact_output(map()) :: String.t()
  def build_compact_output(%{metadata: metadata, summary: summary} = data) do
    warning_lines = extract_warning_lines(data)
    summary_line = Jason.encode!(%{metadata: metadata, summary: summary})

    (warning_lines ++ [summary_line])
    |> Enum.join("\n")
  end

  @doc false
  # Extracts individual warnings as JSON strings for JSONL output.
  # Handles flat lists, grouped maps (from --group-by-warning), and file groups (from --group-by-file).
  @spec extract_warning_lines(map()) :: [String.t()]
  defp extract_warning_lines(%{warnings: warnings}) when is_list(warnings) do
    Enum.map(warnings, &Jason.encode!/1)
  end

  defp extract_warning_lines(%{warnings: warnings}) when is_map(warnings) do
    # Flatten grouped warnings back to individual lines
    warnings
    |> Map.values()
    |> List.flatten()
    |> Enum.map(&Jason.encode!/1)
  end

  defp extract_warning_lines(%{groups: groups}) when is_list(groups) do
    # Flatten file groups back to individual warning lines
    groups
    |> Enum.flat_map(& &1.warnings)
    |> Enum.map(&Jason.encode!/1)
  end

  defp extract_warning_lines(_no_warnings) do
    # --summary-only mode, no warnings or groups key
    []
  end

  @doc false
  # When --quiet is used without explicit --output, auto-buffer to temp file.
  # This ensures stdout pollution doesn't corrupt JSON when piping.
  @spec maybe_use_temp_output(keyword()) :: {keyword(), String.t() | nil}
  defp maybe_use_temp_output(opts) do
    quiet? = Keyword.get(opts, :quiet, false)
    has_output? = Keyword.has_key?(opts, :output)

    if quiet? and not has_output? do
      temp_path =
        Path.join(System.tmp_dir!(), "dialyzer_json_#{System.unique_integer([:positive])}.json")

      {Keyword.put(opts, :output, temp_path), temp_path}
    else
      {opts, nil}
    end
  end

  @doc false
  # Outputs buffered JSON from temp file and cleans up.
  @spec output_buffered_json(String.t()) :: :ok
  defp output_buffered_json(path) do
    case File.read(path) do
      {:ok, content} ->
        IO.write(content)
        File.rm(path)
        :ok

      {:error, _} ->
        # File might not exist if dialyzer crashed early
        :ok
    end
  end
end
