defmodule DialyzerJson.FixHint do
  @moduledoc """
  Classifies dialyzer warning types into fix categories.

  Categories help AI editors prioritize which warnings to fix first:

  - `"spec"` - Likely needs typespec fix. The code is probably correct,
    but the @spec doesn't match what dialyzer inferred.

  - `"code"` - Likely a real bug. The code has a problem that should be fixed,
    such as unreachable code, impossible pattern matches, or invalid calls.

  - `"pattern"` - Common safe-to-ignore pattern. Often intentional or caused by
    third-party code (e.g., missing behaviour info, unused functions).
  """

  @typedoc """
  Fix hint category string.

  Possible values: `"spec"`, `"code"`, `"pattern"`, `"unknown"`
  """
  @type hint :: String.t()

  # Contract/typespec issues - the @spec needs adjustment
  @spec_warnings [
    :contract_diff,
    :contract_range,
    :contract_subtype,
    :contract_supertype,
    :contract_with_opaque,
    :extra_range,
    :invalid_contract,
    :missing_range,
    :overlapping_contract,
    # Callback spec issues (your @impl spec doesn't match behaviour's @callback)
    :callback_spec_arg_type_mismatch,
    :callback_spec_type_mismatch
  ]

  # Code issues - likely real bugs requiring code changes
  @code_warnings [
    # Call/apply failures - calling something that won't work
    :app_call,
    :apply,
    :call,
    :call_to_missing,
    :call_with_opaque,
    :call_without_opaque,
    :fun_app_args,
    :fun_app_no_fun,
    :unknown_function,
    :unknown_type,
    # Guard/pattern failures - logic errors
    :exact_eq,
    :exact_compare,
    :guard_fail,
    :guard_fail_pat,
    :neg_guard_fail,
    :pattern_match,
    :pattern_match_cov,
    # Data construction failures
    :bin_construction,
    :improper_list_constr,
    :map_update,
    :record_constr,
    :record_match,
    :record_matching,
    # Opaque type violations
    :opaque_eq,
    :opaque_guard,
    :opaque_match,
    :opaque_neq,
    :opaque_type_test,
    # Control flow issues
    :no_return,
    # Callback implementation issues (your code doesn't match behaviour spec)
    :callback_arg_type_mismatch,
    :callback_missing,
    :callback_not_exported,
    :callback_type_mismatch
  ]

  # Common patterns - often safe to ignore or suppress
  @pattern_warnings [
    # Third-party behaviour issues
    :callback_info_missing,
    :unknown_behaviour,
    # Often intentional
    :unmatched_return,
    :unused_fun
  ]

  @all_warnings @spec_warnings ++ @code_warnings ++ @pattern_warnings

  @doc """
  Returns the fix hint for a warning type.

  ## Examples

      iex> DialyzerJson.FixHint.classify(:contract_diff)
      "spec"

      iex> DialyzerJson.FixHint.classify(:call)
      "code"

      iex> DialyzerJson.FixHint.classify(:unused_fun)
      "pattern"

      iex> DialyzerJson.FixHint.classify(:unknown_warning_type)
      "unknown"
  """
  @spec classify(atom()) :: hint()
  def classify(warning_type) when warning_type in @spec_warnings, do: "spec"
  def classify(warning_type) when warning_type in @code_warnings, do: "code"
  def classify(warning_type) when warning_type in @pattern_warnings, do: "pattern"
  def classify(_warning_type), do: "unknown"

  @doc """
  Returns a list of all known warning types.
  """
  @spec all_warning_types() :: [atom()]
  def all_warning_types, do: @all_warnings

  @doc """
  Returns warning types for a given category.

  ## Examples

      iex> :contract_diff in DialyzerJson.FixHint.warning_types_for("spec")
      true
  """
  @spec warning_types_for(hint()) :: [atom()]
  def warning_types_for("spec"), do: @spec_warnings
  def warning_types_for("code"), do: @code_warnings
  def warning_types_for("pattern"), do: @pattern_warnings
  def warning_types_for(_), do: []
end
