defmodule GitHubWebhook.MixProject do
  use Mix.Project

  def project do
    [
      app: :github_webhook,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.4"}
    ]
  end
end
