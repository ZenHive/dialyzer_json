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

    test "extracts module and function for contract_diff warnings" do
      # contract_diff: [module, function, arity, contract, signature]
      warning =
        {:warn_contract, {~c"lib/foo.ex", 10},
         {:contract_diff, [MyModule, :my_func, 2, "contract", "signature"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "MyModule"
      assert result.function == "my_func/2"
      assert result.warning_type == "contract_diff"
    end

    test "extracts module and function for contract_subtype warnings" do
      # contract_subtype: [module, function, arity, contract, signature]
      warning =
        {:warn_contract, {~c"lib/foo.ex", 10},
         {:contract_subtype, [SomeModule, :process, 3, "contract", "signature"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "SomeModule"
      assert result.function == "process/3"
    end

    test "extracts module and function for contract_range warnings" do
      # contract_range has different order: [contract, module, function, arg_strings, line, return]
      warning =
        {:warn_contract, {~c"lib/foo.ex", 10},
         {:contract_range, ["contract", MyModule, :handle, [:any, :any], 15, "return_type"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "MyModule"
      assert result.function == "handle/2"
    end

    test "extracts module and function for extra_range warnings" do
      # extra_range: [module, function, arity, extra_ranges, signature_range]
      warning =
        {:warn_contract, {~c"lib/foo.ex", 10}, {:extra_range, [Example, :ok, 0, "extra", "sig"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "Example"
      assert result.function == "ok/0"
    end

    test "extracts behaviour and function for callback_type_mismatch warnings" do
      # callback_type_mismatch: [behaviour, function, arity, fail_type, success_type]
      warning =
        {:warn_callback, {~c"lib/foo.ex", 10},
         {:callback_type_mismatch, [GenServer, :handle_call, 3, "fail", "success"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "GenServer"
      assert result.function == "handle_call/3"
    end

    test "extracts behaviour and function for callback_missing warnings" do
      # callback_missing: [behaviour, function, arity]
      warning =
        {:warn_callback, {~c"lib/foo.ex", 10}, {:callback_missing, [GenServer, :init, 1]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "GenServer"
      assert result.function == "init/1"
    end

    test "extracts behaviour and function for callback_arg_type_mismatch warnings" do
      # callback_arg_type_mismatch: [behaviour, function, arity, position, success_type, callback_type]
      warning =
        {:warn_callback, {~c"lib/foo.ex", 10},
         {:callback_arg_type_mismatch, [MyBehaviour, :process, 2, 1, "actual", "expected"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "MyBehaviour"
      assert result.function == "process/2"
    end

    test "extracts behaviour and function for callback_spec_type_mismatch warnings" do
      # callback_spec_type_mismatch: [behaviour, function, arity, success_type, callback_type]
      warning =
        {:warn_callback, {~c"lib/foo.ex", 10},
         {:callback_spec_type_mismatch, [Supervisor, :child_spec, 1, "actual", "expected"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "Supervisor"
      assert result.function == "child_spec/1"
    end

    test "extracts behaviour and function for callback_not_exported warnings" do
      # callback_not_exported: [behaviour, function, arity]
      warning =
        {:warn_callback, {~c"lib/foo.ex", 10},
         {:callback_not_exported, [GenServer, :handle_cast, 2]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "GenServer"
      assert result.function == "handle_cast/2"
    end

    test "handles charlist module names in contract warnings" do
      # Some dialyzer versions may return charlists for module names
      warning =
        {:warn_contract, {~c"lib/foo.ex", 10},
         {:contract_diff, [~c"Elixir.MyModule", :func, 1, "c", "s"]}}

      result = WarningEncoder.encode_warning(warning)

      assert result.module == "Elixir.MyModule"
      assert result.function == "func/1"
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
