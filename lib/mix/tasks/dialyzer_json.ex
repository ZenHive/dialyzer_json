defmodule Mix.Tasks.Dialyzer.Json do
  @shortdoc "Run dialyzer with JSON output"

  @moduledoc """
  Runs dialyzer and outputs warnings as JSON.

  This task wraps dialyxir's dialyzer task and transforms the output to JSON,
  optimized for AI code editors (Claude Code, Cursor, etc.).

  ## Usage

      mix dialyzer.json
      mix dialyzer.json --quiet

  ## Options

    * `--quiet` - Suppress non-JSON output for clean piping
    * `--summary-only` - Output only counts by warning type, no details
    * `--group-by-warning` - Group warnings by type in output
    * `--output FILE` - Write JSON to file instead of stdout

  ## Output Format

  The output is a JSON object with:

      {
        "warnings": [...],      // Array of warning objects
        "summary": {            // Summary statistics
          "total": 5,
          "by_type": {"no_return": 2, "call": 3}
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
        "raw_message": "Function bar/2 has no local return."
      }
  """

  use Mix.Task

  alias DialyzerJson.WarningEncoder

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
    warnings = run_dialyzer()

    # Encode to JSON
    encoded = encode_output(warnings, opts)

    # Output
    output_json(encoded, opts)

    # If we used temp buffering, output JSON now (after all other stdout pollution)
    if temp_output_path do
      output_buffered_json(temp_output_path)
    end

    # Exit with appropriate code
    if warnings == [] or opts[:ignore_exit_status] do
      :ok
    else
      Mix.raise("Dialyzer found #{length(warnings)} warning(s)")
    end
  end

  @doc false
  # Parses command-line arguments into options keyword list
  @spec extract_opts([String.t()]) :: {keyword(), [String.t()]}
  def extract_opts(args), do: do_extract_opts(args, [], [])

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

  defp do_extract_opts(["--output", path | rest], opts, remaining) do
    do_extract_opts(rest, [{:output, path} | opts], remaining)
  end

  defp do_extract_opts(["--ignore-exit-status" | rest], opts, remaining) do
    do_extract_opts(rest, [{:ignore_exit_status, true} | opts], remaining)
  end

  defp do_extract_opts([arg | rest], opts, remaining) do
    do_extract_opts(rest, opts, [arg | remaining])
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
  # Runs dialyzer and returns the list of warnings
  @spec run_dialyzer() :: [WarningEncoder.warning()]
  defp run_dialyzer do
    # Runtime calls to avoid compile-time warnings when used as a path dependency
    # credo:disable-for-lines:2 Credo.Check.Refactor.Apply
    plt_file = apply(Dialyxir.Project, :plt_file, [])
    files = apply(Dialyxir.Project, :dialyzer_files, [])

    args = [
      check_plt: false,
      init_plt: String.to_charlist(plt_file),
      files: files,
      warnings: [:unknown]
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
    encoded_warnings = WarningEncoder.encode_warnings(warnings)

    summary = %{
      total: length(encoded_warnings),
      by_type: count_by_type(encoded_warnings)
    }

    if opts[:summary_only] do
      %{summary: summary}
    else
      warnings_output =
        if opts[:group_by_warning] do
          group_by_type(encoded_warnings)
        else
          encoded_warnings
        end

      %{
        warnings: warnings_output,
        summary: summary
      }
    end
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
  # Groups warnings by warning type into a map
  @spec group_by_type([WarningEncoder.encoded_warning()]) :: %{
          String.t() => [WarningEncoder.encoded_warning()]
        }
  def group_by_type(warnings) do
    Enum.group_by(warnings, & &1.warning_type)
  end

  @doc false
  # Outputs JSON to stdout or file based on options
  @spec output_json(map(), keyword()) :: :ok
  defp output_json(data, opts) do
    json = Jason.encode!(data, pretty: true)

    case opts[:output] do
      nil -> IO.puts(json)
      path -> File.write!(path, json <> "\n")
    end

    :ok
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
