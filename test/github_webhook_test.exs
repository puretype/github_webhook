defmodule GitHubWebhookTest do
  use ExUnit.Case, async: true
  use Plug.Test

  # Demo plug with basic auth and a simple index action
  defmodule DemoPlug do
    use Plug.Builder

    plug(GitHubWebhook, secret: "secret", path: "/gh-webhook", action: {__MODULE__, :gh_webhook})
    plug(:next_in_chain)

    def gh_webhook(_conn, payload, _opts) do
      Process.put(:payload, payload)
    end

    def next_in_chain(conn, _opts) do
      Process.put(:next_in_chain_called, true)
      conn |> send_resp(200, "OK") |> halt
    end
  end

  test "when verification fails, returns a 403" do
    conn =
      conn(:get, "/gh-webhook", "hello world")
      |> put_req_header("x-hub-signature", "sha1=wrong_hexdigest")
      |> DemoPlug.call([])

    assert conn.status == 403
    assert Process.get(:payload) == nil
    assert !Process.get(:next_in_chain_called)
  end

  test "when payload is verified, returns a 200" do
    hexdigest =
      "sha1=" <>
        (:crypto.mac(:hmac, :sha, "secret", "hello world") |> Base.encode16(case: :lower))

    conn =
      conn(:get, "/gh-webhook", "hello world")
      |> put_req_header("x-hub-signature", hexdigest)
      |> DemoPlug.call([])

    assert conn.status == 200
    assert Process.get(:payload) == "hello world"
    assert !Process.get(:next_in_chain_called)
  end

  test "when path does not match, skips this plug and proceeds to next one" do
    conn =
      conn(:get, "/hello")
      |> DemoPlug.call([])

    assert conn.status == 200
    assert !Process.get(:payload)
    assert Process.get(:next_in_chain_called)
  end

  test "when secret set in param, it takes presedence over application setting" do
    # Demo plug where secret is in ENV var
    defmodule DemoPlugParamPresendence do
      use Plug.Builder

      plug(GitHubWebhook,
        secret: "secret",
        path: "/gh-webhook",
        action: {__MODULE__, :gh_webhook}
      )

      def gh_webhook(_conn, payload, _opts) do
        Process.put(:payload, payload)
      end
    end

    Application.put_env(:github_webhook, :secret, "wrong")

    hexdigest =
      "sha1=" <>
        (:crypto.mac(:hmac, :sha, "secret", "hello world") |> Base.encode16(case: :lower))

    conn =
      conn(:get, "/gh-webhook", "hello world")
      |> put_req_header("x-hub-signature", hexdigest)
      |> DemoPlugParamPresendence.call([])

    assert conn.status == 200
    assert Process.get(:payload) == "hello world"
  end

  test "when secret is not set in params, it uses application setting" do
    # Demo plug where secret is in Application config
    defmodule DemoPlugApplicationSecret do
      use Plug.Builder

      plug(GitHubWebhook, path: "/gh-webhook", action: {__MODULE__, :gh_webhook})

      def gh_webhook(_conn, payload, _opts) do
        Process.put(:payload, payload)
      end
    end

    Application.put_env(:github_webhook, :secret, "1234")

    hexdigest =
      "sha1=" <> (:crypto.mac(:hmac, :sha, "1234", "hello world") |> Base.encode16(case: :lower))

    conn =
      conn(:get, "/gh-webhook", "hello world")
      |> put_req_header("x-hub-signature", hexdigest)
      |> DemoPlugApplicationSecret.call([])

    assert conn.status == 200
    assert Process.get(:payload) == "hello world"
  end

  test "when secret is not set in params or Application setting, it assumes an empty secret" do
    # Demo plug where secret is in ENV var
    defmodule DemoPlugNoSecret do
      use Plug.Builder

      plug(GitHubWebhook, path: "/gh-webhook", action: {__MODULE__, :gh_webhook})

      def gh_webhook(_conn, payload, _opts) do
        Process.put(:payload, payload)
      end
    end

    Application.delete_env(:github_webhook, :secret)

    hexdigest =
      "sha1=" <> (:crypto.mac(:hmac, :sha, "", "hello world") |> Base.encode16(case: :lower))

    conn =
      conn(:get, "/gh-webhook", "hello world")
      |> put_req_header("x-hub-signature", hexdigest)
      |> DemoPlugNoSecret.call([])

    assert conn.status == 200
    assert Process.get(:payload) == "hello world"
  end
end
