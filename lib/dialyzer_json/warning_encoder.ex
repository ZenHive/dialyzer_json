defmodule DialyzerJson.WarningEncoder do
  @moduledoc """
  Encodes Dialyzer warnings to JSON-serializable maps.

  Dialyzer warnings come as tuples:
  `{tag, {file, location}, {warning_type, args}}`

  This module converts them to structured maps suitable for JSON encoding.
  """

  @typedoc "A raw Dialyzer warning tuple"
  @type warning :: {atom(), {charlist() | binary(), location()}, {atom(), list()}}

  @typedoc "Location can be line number or {line, column}"
  @type location :: non_neg_integer() | {non_neg_integer(), non_neg_integer()}

  @typedoc "JSON-serializable warning map"
  @type encoded_warning :: %{
          file: String.t(),
          line: non_neg_integer(),
          column: non_neg_integer() | nil,
          warning_type: String.t(),
          message: String.t(),
          raw_message: String.t(),
          function: String.t() | nil,
          module: String.t() | nil,
          fix_hint: String.t()
        }

  @doc """
  Encodes a list of Dialyzer warnings to JSON-serializable maps.

  ## Examples

      warnings = [{:warn_return_no_exit, {'lib/foo.ex', 10}, {:no_return, [:only_normal, :foo, 2]}}]
      encode_warnings(warnings)
      [%{file: "lib/foo.ex", line: 10, warning_type: "no_return", ...}]
  """
  @spec encode_warnings([warning()]) :: [encoded_warning()]
  def encode_warnings(warnings) when is_list(warnings) do
    Enum.map(warnings, &encode_warning/1)
  end

  @doc """
  Encodes a single Dialyzer warning to a JSON-serializable map.

  ## Example

      iex> warning = {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :bar, 2]}}
      iex> encoded = DialyzerJson.WarningEncoder.encode_warning(warning)
      iex> encoded.file
      "lib/foo.ex"
      iex> encoded.warning_type
      "no_return"
      iex> encoded.function
      "bar/2"
  """
  @spec encode_warning(warning()) :: encoded_warning()
  def encode_warning({_tag, {file, location}, {warning_type, args}}) do
    {line, column} = normalize_location(location)

    %{
      file: make_relative(normalize_file(file)),
      line: line,
      column: column,
      warning_type: to_string(warning_type),
      message: format_message(warning_type, args),
      raw_message: format_raw_message(warning_type, args),
      function: extract_function(warning_type, args),
      module: extract_module(warning_type, args),
      fix_hint: DialyzerJson.FixHint.classify(warning_type)
    }
  end

  @doc false
  # Normalizes location to {line, column} tuple format
  @spec normalize_location(location()) :: {non_neg_integer(), non_neg_integer() | nil}
  defp normalize_location({line, column}) when is_integer(line) and is_integer(column) do
    {line, column}
  end

  defp normalize_location(line) when is_integer(line), do: {line, nil}
  defp normalize_location(_), do: {0, nil}

  @doc false
  # Converts charlist or binary file paths to String
  @spec normalize_file(charlist() | binary()) :: String.t()
  defp normalize_file(file) when is_list(file), do: List.to_string(file)
  defp normalize_file(file) when is_binary(file), do: file
  defp normalize_file(_), do: ""

  @doc false
  # Makes absolute paths relative to current working directory
  @spec make_relative(String.t()) :: String.t()
  defp make_relative(path) do
    cwd = File.cwd!()

    if String.starts_with?(path, cwd) do
      path
      |> String.trim_leading(cwd)
      |> String.trim_leading("/")
    else
      path
    end
  end

  @doc false
  # Uses dialyxir's warning modules when available for friendly messages
  @spec format_message(atom(), list()) :: String.t()
  defp format_message(warning_type, args) do
    case get_dialyxir_warning_module(warning_type) do
      nil -> format_raw_message(warning_type, args)
      module -> module.format_short(args)
    end
  end

  @doc false
  # Formats the raw message using dialyzer's built-in formatting.
  # Falls back to inspect-based format if dialyzer can't format the warning.
  @spec format_raw_message(atom(), list()) :: String.t()
  defp format_raw_message(warning_type, args) do
    :dialyzer.format_warning({:warn, {~c"", 0}, {warning_type, args}})
    |> List.to_string()
    |> String.trim()
  catch
    _kind, _reason -> "#{warning_type}: #{inspect(args)}"
  end

  @doc false
  # Looks up dialyxir's warning module for friendly message formatting (private API, may change)
  @spec get_dialyxir_warning_module(atom()) :: module() | nil
  defp get_dialyxir_warning_module(warning_type) do
    # Runtime check to avoid compile-time warnings when used as a path dependency
    with true <- Code.ensure_loaded?(Dialyxir.Warnings),
         true <- function_exported?(Dialyxir.Warnings, :warnings, 0) do
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      warnings = apply(Dialyxir.Warnings, :warnings, [])
      Map.get(warnings, warning_type)
    else
      _ -> nil
    end
  end

  # Contract warnings with [module, function, arity, ...] pattern
  @contract_mfa_warnings [
    :contract_diff,
    :contract_subtype,
    :contract_supertype,
    :contract_with_opaque,
    :extra_range,
    :invalid_contract,
    :missing_range,
    :overlapping_contract
  ]

  # Callback warnings with [behaviour, function, arity, ...] pattern
  @callback_bfa_warnings [
    :callback_arg_type_mismatch,
    :callback_missing,
    :callback_not_exported,
    :callback_spec_arg_type_mismatch,
    :callback_spec_type_mismatch,
    :callback_type_mismatch
  ]

  @doc false
  # Extracts function name from warning args when available
  @spec extract_function(atom(), list()) :: String.t() | nil
  defp extract_function(:no_return, [_type | name_args]) do
    case name_args do
      [function, arity] -> "#{function}/#{arity}"
      [] -> nil
    end
  end

  defp extract_function(:call, [_module, function, args | _rest]) do
    "#{function}/#{length(args)}"
  end

  # Contract warnings: [module, function, arity, ...]
  defp extract_function(warning_type, [_module, function, arity | _rest])
       when warning_type in @contract_mfa_warnings and is_integer(arity) do
    "#{function}/#{arity}"
  end

  # Contract range has different order: [contract, module, function, arg_strings, ...]
  defp extract_function(:contract_range, [_contract, _module, function, arg_strings | _rest])
       when is_list(arg_strings) do
    "#{function}/#{length(arg_strings)}"
  end

  # Callback warnings: [behaviour, function, arity, ...]
  defp extract_function(warning_type, [_behaviour, function, arity | _rest])
       when warning_type in @callback_bfa_warnings and is_integer(arity) do
    "#{function}/#{arity}"
  end

  defp extract_function(_warning_type, _args), do: nil

  @doc false
  # Extracts module name from warning args when available
  @spec extract_module(atom(), list()) :: String.t() | nil
  defp extract_module(:call, [module | _rest]) do
    format_module(module)
  end

  # Contract warnings: [module, function, arity, ...]
  defp extract_module(warning_type, [module | _rest])
       when warning_type in @contract_mfa_warnings do
    format_module(module)
  end

  # Contract range has different order: [contract, module, function, ...]
  defp extract_module(:contract_range, [_contract, module | _rest]) do
    format_module(module)
  end

  # Callback warnings: [behaviour, function, arity, ...]
  # Returns the behaviour module as the relevant module context
  defp extract_module(warning_type, [behaviour | _rest])
       when warning_type in @callback_bfa_warnings do
    format_module(behaviour)
  end

  defp extract_module(_warning_type, _args), do: nil

  @doc false
  # Formats a module for JSON output, handling both atoms and charlists
  @spec format_module(atom() | charlist()) :: String.t()
  defp format_module(module) when is_atom(module), do: inspect(module)
  defp format_module(module) when is_list(module), do: List.to_string(module)
  defp format_module(module) when is_binary(module), do: module
end
