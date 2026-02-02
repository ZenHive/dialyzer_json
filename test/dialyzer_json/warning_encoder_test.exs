defmodule DialyzerJson.WarningEncoderTest do
  use ExUnit.Case, async: true

  alias DialyzerJson.WarningEncoder

  describe "encode_warning/1" do
    test "encodes a basic warning with line number" do
      warning =
        {:warn_return_no_exit, {~c"lib/foo.ex", 42}, {:no_return, [:only_normal, :bar, 2]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.file == "lib/foo.ex"
      assert result.line == 42
      assert result.column == nil
      assert result.warning_type == "no_return"
      assert result.function == "bar/2"
      assert is_binary(result.message)
      assert is_binary(result.raw_message)
    end

    test "encodes a warning with line and column" do
      warning =
        {:warn_return_no_exit, {~c"lib/foo.ex", {42, 5}}, {:no_return, [:only_normal, :bar, 2]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.line == 42
      assert result.column == 5
    end

    test "handles binary file paths" do
      warning = {:warn_return_no_exit, {"lib/foo.ex", 10}, {:no_return, [:only_normal, :baz, 1]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.file == "lib/foo.ex"
    end

    test "makes absolute paths relative to cwd" do
      cwd = File.cwd!()
      abs_path = Path.join(cwd, "lib/foo.ex")

      warning =
        {:warn_return_no_exit, {String.to_charlist(abs_path), 10}, {:no_return, [:only_normal]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.file == "lib/foo.ex"
    end

    test "extracts function for no_return warnings" do
      warning =
        {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :my_func, 3]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.function == "my_func/3"
    end

    test "returns nil function for anonymous no_return warnings" do
      warning = {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.function == nil
    end

    test "extracts function and module for call warnings" do
      # Use valid dialyzer call warning format:
      # {:call, [Module, Function, ArgTypes, ArgNs, FailReason, SigArgs, SigRet, Contract]}
      warning =
        {:warn_failing_call, {~c"lib/foo.ex", 10},
         {:call,
          [
            SomeModule,
            :my_func,
            [:any, :any, :any],
            [1, 2, 3],
            :only_sig,
            "(any(), any(), any())",
            "any()",
            :none
          ]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.function == "my_func/3"
      assert result.module == "SomeModule"
      assert result.warning_type == "call"
      assert result.fix_hint == "code"
    end

    test "includes fix_hint for code warnings" do
      warning =
        {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :bar, 2]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.fix_hint == "code"
    end

    test "includes fix_hint for spec warnings" do
      warning =
        {:warn_contract, {~c"lib/foo.ex", 10},
         {:contract_diff, [:Mod, :func, 1, "contract", "sig"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.fix_hint == "spec"
    end

    test "includes fix_hint for pattern warnings" do
      # unused_fun is a pattern warning
      warning = {:warn_unused, {~c"lib/foo.ex", 10}, {:unused_fun, [:my_func, 1]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.fix_hint == "pattern"
    end
  end

  describe "encode_warnings/1" do
    test "encodes multiple warnings" do
      warnings = [
        {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :foo, 1]}},
        {:warn_return_no_exit, {~c"lib/bar.ex", 20}, {:no_return, [:only_normal, :bar, 2]}}
      ]

      results = WarningEncoder.encode_warnings(warnings)

      assert length(results) == 2
      assert Enum.at(results, 0).file == "lib/foo.ex"
      assert Enum.at(results, 1).file == "lib/bar.ex"
    end

    test "returns empty list for no warnings" do
      assert WarningEncoder.encode_warnings([]) == []
    end
  end
end
