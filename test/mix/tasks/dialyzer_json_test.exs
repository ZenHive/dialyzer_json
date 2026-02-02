defmodule Mix.Tasks.Dialyzer.JsonTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Dialyzer.Json, as: Task

  describe "extract_opts/1" do
    test "parses --quiet flag" do
      {opts, remaining} = Task.extract_opts(["--quiet"])

      assert opts[:quiet] == true
      assert remaining == []
    end

    test "parses --summary-only flag" do
      {opts, _remaining} = Task.extract_opts(["--summary-only"])

      assert opts[:summary_only] == true
    end

    test "parses --group-by-warning flag" do
      {opts, _remaining} = Task.extract_opts(["--group-by-warning"])

      assert opts[:group_by_warning] == true
    end

    test "parses --output with path" do
      {opts, _remaining} = Task.extract_opts(["--output", "/tmp/output.json"])

      assert opts[:output] == "/tmp/output.json"
    end

    test "parses --ignore-exit-status flag" do
      {opts, _remaining} = Task.extract_opts(["--ignore-exit-status"])

      assert opts[:ignore_exit_status] == true
    end

    test "preserves unknown arguments as remaining" do
      {opts, remaining} = Task.extract_opts(["--quiet", "--unknown", "value"])

      assert opts[:quiet] == true
      assert remaining == ["--unknown", "value"]
    end

    test "handles multiple flags" do
      {opts, _remaining} = Task.extract_opts(["--quiet", "--summary-only", "--group-by-warning"])

      assert opts[:quiet] == true
      assert opts[:summary_only] == true
      assert opts[:group_by_warning] == true
    end

    test "returns empty opts for no arguments" do
      {opts, remaining} = Task.extract_opts([])

      assert opts == []
      assert remaining == []
    end
  end

  describe "count_by_type/1" do
    test "counts warnings by type" do
      warnings = [
        %{warning_type: "no_return", file: "a.ex", line: 1},
        %{warning_type: "no_return", file: "b.ex", line: 2},
        %{warning_type: "call", file: "c.ex", line: 3}
      ]

      result = Task.count_by_type(warnings)

      assert result == %{"no_return" => 2, "call" => 1}
    end

    test "returns empty map for no warnings" do
      assert Task.count_by_type([]) == %{}
    end
  end

  describe "group_by_type/1" do
    test "groups warnings by type" do
      warning1 = %{warning_type: "no_return", file: "a.ex", line: 1}
      warning2 = %{warning_type: "no_return", file: "b.ex", line: 2}
      warning3 = %{warning_type: "call", file: "c.ex", line: 3}

      result = Task.group_by_type([warning1, warning2, warning3])

      assert result == %{
               "no_return" => [warning1, warning2],
               "call" => [warning3]
             }
    end

    test "returns empty map for no warnings" do
      assert Task.group_by_type([]) == %{}
    end
  end

  describe "count_by_fix_hint/1" do
    test "counts warnings by fix hint" do
      warnings = [
        %{fix_hint: "code", warning_type: "no_return"},
        %{fix_hint: "code", warning_type: "call"},
        %{fix_hint: "spec", warning_type: "contract_diff"}
      ]

      result = Task.count_by_fix_hint(warnings)

      assert result == %{"code" => 2, "spec" => 1}
    end

    test "returns empty map for no warnings" do
      assert Task.count_by_fix_hint([]) == %{}
    end
  end

  describe "encode_output/2" do
    setup do
      # Create some mock raw warnings that will be processed by WarningEncoder
      raw_warnings = [
        {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :foo, 1]}},
        {:warn_return_no_exit, {~c"lib/bar.ex", 20}, {:no_return, [:only_normal, :bar, 2]}}
      ]

      {:ok, raw_warnings: raw_warnings}
    end

    test "includes warnings and summary by default", %{raw_warnings: raw_warnings} do
      result = Task.encode_output(raw_warnings, [])

      assert Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :summary)
      assert result.summary.total == 2
      assert result.summary.by_type == %{"no_return" => 2}
      assert result.summary.by_fix_hint == %{"code" => 2}
    end

    test "with --summary-only excludes warnings", %{raw_warnings: raw_warnings} do
      result = Task.encode_output(raw_warnings, summary_only: true)

      refute Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :summary)
      assert result.summary.total == 2
    end

    test "with --group-by-warning groups warnings by type", %{raw_warnings: raw_warnings} do
      result = Task.encode_output(raw_warnings, group_by_warning: true)

      assert is_map(result.warnings)
      assert Map.has_key?(result.warnings, "no_return")
      assert length(result.warnings["no_return"]) == 2
    end

    test "without --group-by-warning returns flat list", %{raw_warnings: raw_warnings} do
      result = Task.encode_output(raw_warnings, [])

      assert is_list(result.warnings)
      assert length(result.warnings) == 2
    end

    test "handles empty warnings" do
      result = Task.encode_output([], [])

      assert result.warnings == []
      assert result.summary.total == 0
      assert result.summary.by_type == %{}
      assert result.summary.by_fix_hint == %{}
    end
  end
end
