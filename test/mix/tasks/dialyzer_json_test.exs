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

    test "parses --group-by-file flag" do
      {opts, _remaining} = Task.extract_opts(["--group-by-file"])

      assert opts[:group_by_file] == true
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

  describe "group_by_file/1" do
    test "groups warnings by file path" do
      warning1 = %{warning_type: "no_return", file: "lib/foo.ex", line: 1}
      warning2 = %{warning_type: "call", file: "lib/foo.ex", line: 5}
      warning3 = %{warning_type: "no_return", file: "lib/bar.ex", line: 10}

      result = Task.group_by_file([warning1, warning2, warning3])

      assert length(result) == 2

      # Results should be sorted by file
      [bar_group, foo_group] = result

      assert bar_group.file == "lib/bar.ex"
      assert bar_group.count == 1
      assert bar_group.warnings == [warning3]

      assert foo_group.file == "lib/foo.ex"
      assert foo_group.count == 2
      assert foo_group.warnings == [warning1, warning2]
    end

    test "returns empty list for no warnings" do
      assert Task.group_by_file([]) == []
    end

    test "each group has file, count, and warnings keys" do
      warning = %{warning_type: "no_return", file: "lib/test.ex", line: 1}

      [group] = Task.group_by_file([warning])

      assert Map.keys(group) |> Enum.sort() == [:count, :file, :warnings]
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

  describe "build_metadata/0" do
    test "returns metadata with all required fields" do
      metadata = Task.build_metadata()

      assert metadata.schema_version == "1.0"
      assert is_binary(metadata.dialyzer_version)
      assert is_binary(metadata.elixir_version)
      assert is_binary(metadata.otp_version)
      assert is_binary(metadata.run_at)
    end

    test "run_at is valid ISO8601 timestamp" do
      metadata = Task.build_metadata()

      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(metadata.run_at)
    end

    test "elixir_version matches System.version()" do
      metadata = Task.build_metadata()

      assert metadata.elixir_version == System.version()
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

    test "includes metadata, warnings and summary by default", %{raw_warnings: raw_warnings} do
      result = Task.encode_output(raw_warnings, [])

      assert Map.has_key?(result, :metadata)
      assert Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :summary)
      assert result.metadata.schema_version == "1.0"
      assert result.summary.total == 2
      assert result.summary.by_type == %{"no_return" => 2}
      assert result.summary.by_fix_hint == %{"code" => 2}
    end

    test "with --summary-only excludes warnings but includes metadata", %{
      raw_warnings: raw_warnings
    } do
      result = Task.encode_output(raw_warnings, summary_only: true)

      refute Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :metadata)
      assert Map.has_key?(result, :summary)
      assert result.metadata.schema_version == "1.0"
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

    test "with --group-by-file groups warnings by file path", %{raw_warnings: raw_warnings} do
      result = Task.encode_output(raw_warnings, group_by_file: true)

      # Should have groups key, not warnings key
      assert Map.has_key?(result, :groups)
      refute Map.has_key?(result, :warnings)

      # Groups should be a list of objects
      assert is_list(result.groups)
      assert length(result.groups) == 2

      # Each group should have file, count, and warnings
      Enum.each(result.groups, fn group ->
        assert Map.has_key?(group, :file)
        assert Map.has_key?(group, :count)
        assert Map.has_key?(group, :warnings)
      end)
    end

    test "with --group-by-file sorts groups by file path", %{raw_warnings: raw_warnings} do
      result = Task.encode_output(raw_warnings, group_by_file: true)

      files = Enum.map(result.groups, & &1.file)
      assert files == Enum.sort(files)
    end

    test "with --group-by-file and --filter-type filters then groups across multiple files" do
      # Warnings from 3 files: foo (2 no_return), bar (1 call - filtered out), baz (1 no_return)
      raw_warnings = [
        {:warn_return_no_exit, {~c"lib/foo.ex", 10}, {:no_return, [:only_normal, :foo, 1]}},
        {:warn_return_no_exit, {~c"lib/foo.ex", 20}, {:no_return, [:only_normal, :bar, 2]}},
        {:warn_failing_call, {~c"lib/bar.ex", 30},
         {:call, [:erlang, :+, [1, :a], [1, 2], :error, :only_contract]}},
        {:warn_return_no_exit, {~c"lib/baz.ex", 40}, {:no_return, [:only_normal, :baz, 0]}}
      ]

      result = Task.encode_output(raw_warnings, filter_type: ["no_return"], group_by_file: true)

      # After filtering: 3 no_return warnings, bar.ex filtered out entirely
      assert result.summary.total == 3
      assert length(result.groups) == 2

      # Groups sorted alphabetically: baz.ex, foo.ex (bar.ex filtered out)
      [baz_group, foo_group] = result.groups
      assert baz_group.file == "lib/baz.ex"
      assert baz_group.count == 1
      assert foo_group.file == "lib/foo.ex"
      assert foo_group.count == 2
    end

    test "with --group-by-file takes precedence over --group-by-warning", %{
      raw_warnings: raw_warnings
    } do
      result = Task.encode_output(raw_warnings, group_by_file: true, group_by_warning: true)

      # Should use groups, not warnings
      assert Map.has_key?(result, :groups)
      refute Map.has_key?(result, :warnings)
    end
  end

  describe "build_compact_output/1" do
    test "with warnings produces JSONL" do
      data = %{
        metadata: %{schema_version: "1.0", elixir_version: "1.15.0"},
        warnings: [
          %{warning_type: "no_return", file: "a.ex", line: 1},
          %{warning_type: "call", file: "b.ex", line: 2}
        ],
        summary: %{total: 2, by_type: %{"no_return" => 1, "call" => 1}}
      }

      result = Task.build_compact_output(data)
      lines = String.split(result, "\n")

      # Should have 3 lines: 2 warnings + 1 summary with metadata
      assert length(lines) == 3

      # Each line should be valid JSON
      Enum.each(lines, fn line ->
        assert {:ok, _} = Jason.decode(line), "Line is not valid JSON: #{line}"
      end)

      # Last line should have both metadata and summary
      {:ok, last} = Jason.decode(List.last(lines))
      assert Map.has_key?(last, "metadata")
      assert Map.has_key?(last, "summary")
    end

    test "with grouped warnings flattens to JSONL" do
      data = %{
        metadata: %{schema_version: "1.0"},
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

      # Should have 3 lines: 2 warnings + 1 summary with metadata
      assert length(lines) == 3
    end

    test "with summary-only outputs single line with metadata" do
      data = %{
        metadata: %{schema_version: "1.0", elixir_version: "1.15.0"},
        summary: %{total: 5, by_type: %{"no_return" => 3, "call" => 2}}
      }

      result = Task.build_compact_output(data)
      lines = String.split(result, "\n")

      # Should have just the summary line with metadata
      assert length(lines) == 1
      {:ok, parsed} = Jason.decode(hd(lines))
      assert Map.has_key?(parsed, "metadata")
      assert Map.has_key?(parsed, "summary")
    end

    test "with file groups flattens to JSONL" do
      data = %{
        metadata: %{schema_version: "1.0"},
        groups: [
          %{
            file: "lib/bar.ex",
            count: 1,
            warnings: [%{warning_type: "call", file: "lib/bar.ex", line: 5}]
          },
          %{
            file: "lib/foo.ex",
            count: 2,
            warnings: [
              %{warning_type: "no_return", file: "lib/foo.ex", line: 1},
              %{warning_type: "no_return", file: "lib/foo.ex", line: 10}
            ]
          }
        ],
        summary: %{total: 3, by_type: %{"no_return" => 2, "call" => 1}}
      }

      result = Task.build_compact_output(data)
      lines = String.split(result, "\n")

      # Should have 4 lines: 3 warnings + 1 summary with metadata
      assert length(lines) == 4

      # Each line should be valid JSON
      Enum.each(lines, fn line ->
        assert {:ok, _} = Jason.decode(line), "Line is not valid JSON: #{line}"
      end)
    end
  end
end
