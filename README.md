# GitHubWebhook

A fork from [gh_webhook_plug](https://github.com/emilsoman/gh_webhook_plug), with some additional functionality:

- deserializes the payload into an Elixir data structure
- pass along webhook headers in a keyword list
- updates for OTP functionality and updated Elixir conventions
- uses the `X-Hub-Signature-256` header for verification
    - make sure that you have configured a secret for your webhook

## Usage

Inside a Phoenix application, in the `Endpoint` module:

```elixir
defmodule MyApp.Endpoint do

  plug GitHubWebhook,
    secret: "secret",
    path: "/github_webhook",
    action: {MyApp.GithubWebhook, :handle}

  # Rest of the plugs
end
```

so you can write the handler like so:

```elixir
defmodule MyApp.GithubWebhook do
  @spec handle(Plug.Conn.t(), map(), Keyword.t()) :: any()
  def handle(conn, payload, opts) do
    # Handle webhook payload here
    # opts contains additional values from headers

    # Return value of this function is ignored
  end
end
```

## Configuration

The below variables can be set in your `config/config.exs` or via options to the plug:

```elixir
config :github_webhook,
  # Secret set in webhook settings page of the Github repository
  secret: "foobar",
  # Path that will be intercepted by GhWebhookPlug
  path: "/api/github_webhook",
  # Module and function that will be used to handle the webhook payload
  action: {MyApp.GithubWebhook, :handle}
```

The following options are read at compile-time, and so therefore must be set in `config/config.exs`:

```elixir
config :github_webhook,
  # JSON library used for decoding the incoming request
  json_library: Jason
```

## Installation

The package can be installed by adding `github_webhook` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:github_webhook, "~> 0.2"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/github_webhook>.
