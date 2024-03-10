defmodule GitHubWebhook do
  @moduledoc """
  Handles incoming GitHub hook requests
  """

  import Plug.Conn

  require Logger

  @behaviour Plug

  @request_header_context %{
    "x-github-hook-installation-target-type" => :installation_target_type,
    "x-github-hook-installation-target-id" => :installation_target_id
  }

  @impl true
  def init(options) do
    options
  end

  @doc """
  Verifies secret and calls a handler with the webhook payload
  """
  @impl true
  def call(conn, options) do
    path = get_config(options, :path)

    case conn.request_path do
      ^path ->
        secret = get_config(options, :secret)
        {module, function} = get_config(options, :action)

        {:ok, payload, conn} = read_body(conn)
        [signature_in_header] = get_req_header(conn, "x-hub-signature")

        if verify_signature(payload, secret, signature_in_header) do
          apply(module, function, [conn, payload, request_header_opts(conn)])
          conn |> send_resp(200, "OK") |> halt()
        else
          conn |> send_resp(403, "Forbidden") |> halt()
        end

      _ ->
        conn
    end
  end

  defp verify_signature(payload, secret, signature_in_header) do
    signature =
      "sha1=" <> (:crypto.mac(:hmac, :sha, secret, payload) |> Base.encode16(case: :lower))

    Plug.Crypto.secure_compare(signature, signature_in_header)
  end

  defp get_config(options, key) do
    options[key] || get_config(key)
  end

  defp get_config(key) do
    case Application.fetch_env(:github_webhook, key) do
      :error ->
        Logger.warning("GhWebhookPlug config key #{inspect(key)} is not configured.")
        ""

      {:ok, val} ->
        val
    end
  end

  defp request_header_opts(conn) do
    Enum.reduce(@request_header_context, [], fn {header, key}, acc ->
      case get_req_header(conn, header) do
        [value] -> Keyword.put(acc, key, value)
        _ -> acc
      end
    end)
  end
end
