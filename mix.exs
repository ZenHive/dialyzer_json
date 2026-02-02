defmodule DialyzerJson.MixProject do
  use Mix.Project

  def project do
    [
      app: :dialyzer_json,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
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
      {:tidewave, "~> 0.1", only: :dev},
      {:bandit, "~> 1.0", only: :dev}
    ]
  end
end
