defmodule DialyzerJson.MixProject do
  use Mix.Project

  @source_url "https://github.com/ZenHive/dialyzer_json"

  def project do
    [
      app: :dialyzer_json,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      source_url: @source_url
    ]
  end

  def cli do
    [preferred_envs: ["dialyzer.json": :dev, "test.json": :test]]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :dialyzer, :dialyxir]
    ]
  end

  defp description do
    "AI-friendly JSON output for Dialyzer warnings. Structured output for Claude Code and similar AI editors."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md LICENSE AGENTS.md)
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_unit_json, "~> 0.3", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:tidewave, "~> 0.1", only: :dev},
      {:bandit, "~> 1.0", only: :dev}
    ]
  end
end
