defmodule DialyzerJson.FixHintTest do
  use ExUnit.Case, async: true
  doctest DialyzerJson.FixHint

  alias DialyzerJson.FixHint

  describe "classify/1" do
    test "classifies contract warnings as spec" do
      spec_warnings = [
        :contract_diff,
        :contract_range,
        :contract_subtype,
        :contract_supertype,
        :contract_with_opaque,
        :extra_range,
        :invalid_contract,
        :missing_range,
        :overlapping_contract,
        :callback_spec_arg_type_mismatch,
        :callback_spec_type_mismatch
      ]

      for warning <- spec_warnings do
        assert FixHint.classify(warning) == "spec",
               "Expected #{inspect(warning)} to be classified as 'spec'"
      end
    end

    test "classifies call/pattern failures as code" do
      code_warnings = [
        :call,
        :app_call,
        :apply,
        :exact_compare,
        :guard_fail,
        :pattern_match,
        :no_return,
        :unknown_function,
        :callback_missing
      ]

      for warning <- code_warnings do
        assert FixHint.classify(warning) == "code",
               "Expected #{inspect(warning)} to be classified as 'code'"
      end
    end

    test "classifies common ignore patterns as pattern" do
      pattern_warnings = [
        :callback_info_missing,
        :unknown_behaviour,
        :unmatched_return,
        :unused_fun
      ]

      for warning <- pattern_warnings do
        assert FixHint.classify(warning) == "pattern",
               "Expected #{inspect(warning)} to be classified as 'pattern'"
      end
    end

    test "returns unknown for unrecognized warning types" do
      assert FixHint.classify(:made_up_warning) == "unknown"
      assert FixHint.classify(:future_warning_type) == "unknown"
    end
  end

  describe "all_warning_types/0" do
    test "returns a list of atoms" do
      types = FixHint.all_warning_types()
      assert is_list(types)
      assert Enum.all?(types, &is_atom/1)
    end

    test "includes all dialyxir warning types" do
      # Dialyxir has 47 warning types
      our_types = FixHint.all_warning_types() |> MapSet.new()

      dialyxir_types =
        if Code.ensure_loaded?(Dialyxir.Warnings) do
          Dialyxir.Warnings.warnings() |> Map.keys() |> MapSet.new()
        else
          MapSet.new()
        end

      # Our classification should cover all dialyxir types
      missing = MapSet.difference(dialyxir_types, our_types)

      assert MapSet.size(missing) == 0,
             "Missing warning types: #{inspect(MapSet.to_list(missing))}"
    end

    test "has no duplicate warning types" do
      types = FixHint.all_warning_types()
      unique_types = Enum.uniq(types)
      assert length(types) == length(unique_types), "Found duplicate warning types"
    end
  end

  describe "warning_types_for/1" do
    test "returns spec warning types" do
      types = FixHint.warning_types_for("spec")
      assert :contract_diff in types
      assert :invalid_contract in types
    end

    test "returns code warning types" do
      types = FixHint.warning_types_for("code")
      assert :call in types
      assert :no_return in types
    end

    test "returns pattern warning types" do
      types = FixHint.warning_types_for("pattern")
      assert :unmatched_return in types
      assert :callback_info_missing in types
    end

    test "returns empty list for unknown category" do
      assert FixHint.warning_types_for("unknown") == []
      assert FixHint.warning_types_for("invalid") == []
    end
  end
end
