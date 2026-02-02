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

    test "parses --compact flag" do
      {opts, _remaining} = Task.extract_opts(["--compact"])

      assert opts[:compact] == true
    end

    test "parses single --filter-type" do
      {opts, _remaining} = Task.extract_opts(["--filter-type", "no_return"])

      assert opts[:filter_type] == ["no_return"]
    end

    test "parses multiple --filter-type flags into list" do
      {opts, _remaining} =
        Task.extract_opts(["--filter-type", "no_return", "--filter-type", "call"])

      assert opts[:filter_type] == ["no_return", "call"]
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

  describe "filter_warnings/2" do
    test "returns all warnings when filter is nil" do
      warnings = [
        %{warning_type: "no_return"},
        %{warning_type: "call"}
      ]

      assert Task.filter_warnings(warnings, nil) == warnings
    end

    test "returns all warnings when filter is empty list" do
      warnings = [
        %{warning_type: "no_return"},
        %{warning_type: "call"}
      ]

      assert Task.filter_warnings(warnings, []) == warnings
    end

    test "filters to single type" do
      warnings = [
        %{warning_type: "no_return", file: "a.ex"},
        %{warning_type: "call", file: "b.ex"},
        %{warning_type: "no_return", file: "c.ex"}
      ]

      result = Task.filter_warnings(warnings, ["no_return"])

      assert length(result) == 2
      assert Enum.all?(result, &(&1.warning_type == "no_return"))
    end

    test "filters to multiple types (OR logic)" do
      warnings = [
        %{warning_type: "no_return", file: "a.ex"},
        %{warning_type: "call", file: "b.ex"},
        %{warning_type: "pattern_match", file: "c.ex"}
      ]

      result = Task.filter_warnings(warnings, ["no_return", "call"])

      assert length(result) == 2
      assert Enum.all?(result, &(&1.warning_type in ["no_return", "call"]))
    end

    test "returns empty list when no warnings match filter" do
      warnings = [
        %{warning_type: "no_return"},
        %{warning_type: "call"}
      ]

      assert Task.filter_warnings(warnings, ["unknown_type"]) == []
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

    test "with --filter-type filters warnings and updates summary" do
      # Create warnings with different types
      raw_warnings = [
        {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :foo, 1]}},
        {:warn_failing_call, {~c"lib/bar.ex", 20},
         {:call, [:erlang, :+, [1, :a], [1, 2], :error, :only_contract]}}
      ]

      result = Task.encode_output(raw_warnings, filter_type: ["no_return"])

      assert result.summary.total == 1
      assert result.summary.by_type == %{"no_return" => 1}
      assert length(result.warnings) == 1
      assert hd(result.warnings).warning_type == "no_return"
    end

    test "with --filter-type and --group-by-warning" do
      raw_warnings = [
        {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :foo, 1]}},
        {:warn_return_no_exit, {~c"lib/bar.ex", 20}, {:no_return, [:only_normal, :bar, 2]}},
        {:warn_failing_call, {~c"lib/baz.ex", 30},
         {:call, [:erlang, :+, [1, :a], [1, 2], :error, :only_contract]}}
      ]

      result =
        Task.encode_output(raw_warnings, filter_type: ["no_return"], group_by_warning: true)

      assert result.summary.total == 2
      assert Map.keys(result.warnings) == ["no_return"]
      assert length(result.warnings["no_return"]) == 2
    end
  end

  describe "build_compact_output/1" do
    test "with warnings produces JSONL" do
      data = %{
        warnings: [
          %{warning_type: "no_return", file: "a.ex", line: 1},
          %{warning_type: "call", file: "b.ex", line: 2}
        ],
        summary: %{total: 2, by_type: %{"no_return" => 1, "call" => 1}}
      }

      result = Task.build_compact_output(data)
      lines = String.split(result, "\n")

      # Should have 3 lines: 2 warnings + 1 summary
      assert length(lines) == 3

      # Each line should be valid JSON
      Enum.each(lines, fn line ->
        assert {:ok, _} = Jason.decode(line), "Line is not valid JSON: #{line}"
      end)

      # Last line should be the summary
      {:ok, last} = Jason.decode(List.last(lines))
      assert Map.has_key?(last, "summary")
    end

    test "with grouped warnings flattens to JSONL" do
      data = %{
        warnings: %{
          "no_return" => [
            %{warning_type: "no_return", file: "a.ex", line: 1},
            %{warning_type: "no_return", file: "b.ex", line: 2}
          ]
        },
        summary: %{total: 2, by_type: %{"no_return" => 2}}
      }

      result = Task.build_compact_output(data)
      lines = String.split(result, "\n")

      # Should have 3 lines: 2 warnings + 1 summary
      assert length(lines) == 3
    end

    test "with summary-only outputs single line" do
      data = %{
        summary: %{total: 5, by_type: %{"no_return" => 3, "call" => 2}}
      }

      result = Task.build_compact_output(data)
      lines = String.split(result, "\n")

      # Should have just the summary line
      assert length(lines) == 1
      {:ok, parsed} = Jason.decode(hd(lines))
      assert Map.has_key?(parsed, "summary")
    end
  end
end
