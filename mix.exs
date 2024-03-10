defmodule GitHubWebhook.MixProject do
  use Mix.Project

  def project do
    [
      app: :github_webhook,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: "Github webhook plug",
      package: package(),
      preferred_cli_env: [ci: :test],
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "credo --strict",
        "compile --warnings-as-errors --force",
        "coveralls.html"
      ]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.0", optional: true},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:plug, "~> 1.4"}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/puretype/github_webhook"}
    ]
  end
end
