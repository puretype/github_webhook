defmodule GitHubWebhookTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @test_body %{"hello" => "world"}
  @test_body_serialized Jason.encode!(@test_body)

  # Demo plug with basic auth and a simple index action
  defmodule DemoPlug do
    use Plug.Builder

    plug(GitHubWebhook, secret: "secret", path: "/gh-webhook", action: {__MODULE__, :gh_webhook})
    plug(:next_in_chain)

    def gh_webhook(_conn, payload, opts) do
      Process.put(:payload, payload)
      Process.put(:opts, opts)
    end

    def next_in_chain(conn, _opts) do
      Process.put(:next_in_chain_called, true)
      conn |> send_resp(200, "OK") |> halt
    end
  end

  test "when verification fails, returns a 403" do
    conn =
      gh_webhook_request()
      |> put_req_header("x-hub-signature", "sha1=wrong_hexdigest")
      |> DemoPlug.call([])

    assert conn.status == 403
    assert Process.get(:payload) == nil
    assert !Process.get(:next_in_chain_called)
  end

  test "when payload is verified, returns a 200" do
    conn =
      gh_webhook_request()
      |> DemoPlug.call([])

    assert conn.status == 200
    assert Process.get(:payload) == @test_body_serialized
    assert !Process.get(:next_in_chain_called)
  end

  test "passes GitHub headers as keyword options" do
    conn =
      gh_webhook_request()
      |> put_req_header("x-github-hook-installation-target-id", "123")
      |> DemoPlug.call([])

    assert conn.status == 200
    assert Process.get(:opts) == [{:installation_target_id, "123"}]
  end

  test "deserializes JSON payload" do
    conn =
      gh_webhook_request(%{"hello" => "world"})
      |> DemoPlug.call([])

    assert conn.status == 200
    assert Process.get(:payload) == @test_body_serialized
  end

  test "when path does not match, skips this plug and proceeds to next one" do
    conn =
      conn(:post, "/hello")
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

    conn =
      gh_webhook_request(@test_body)
      |> DemoPlugParamPresendence.call([])

    assert conn.status == 200
    assert Process.get(:payload) == @test_body_serialized
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

    conn =
      gh_webhook_request(%{"hello" => "world"}, "1234")
      |> DemoPlugApplicationSecret.call([])

    assert conn.status == 200
    assert Process.get(:payload) == @test_body_serialized
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

    conn =
      gh_webhook_request(@test_body, "")
      |> DemoPlugNoSecret.call([])

    assert conn.status == 200
    assert Process.get(:payload) == @test_body_serialized
  end

  defp gh_webhook_request(body \\ %{"hello" => "world"}, secret \\ "secret") do
    body = Jason.encode!(body)

    hexdigest =
      "sha1=" <>
        (:crypto.mac(:hmac, :sha, secret, body) |> Base.encode16(case: :lower))

    conn(:post, "/gh-webhook", body)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-hub-signature", hexdigest)
  end
end
