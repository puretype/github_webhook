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

  defmodule CacheBodyReader do
    @moduledoc false

    def read_body(conn, opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end

  @plug_parser Plug.Parsers.init(
                 parsers: [:json],
                 body_reader: {CacheBodyReader, :read_body, []},
                 json_decoder: Application.compile_env(:github_webhook, :json_library, Jason)
               )

  #

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

        conn = Plug.Parsers.call(conn, @plug_parser)

        [signature_in_header] = get_req_header(conn, "x-hub-signature-256")

        if verify_signature(conn.assigns.raw_body, secret, signature_in_header) do
          apply(module, function, [conn, conn.body_params, request_header_opts(conn)])
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
      "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower))

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
