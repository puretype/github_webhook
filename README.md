# GitHubWebhook

A fork from [gh_webhook_plug](https://github.com/emilsoman/gh_webhook_plug), with some additional functionality:

- pass along webhook headers in a keyword list
- updates for OTP functionality and updated Elixir conventions

## Installation

The package can be installed by adding `github_webhook` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:github_webhook, "~> 0.1.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/github_webhook>.
