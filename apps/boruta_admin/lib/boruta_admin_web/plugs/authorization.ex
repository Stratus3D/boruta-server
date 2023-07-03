defmodule BorutaAdminWeb.Authorization do
  @moduledoc false
  @dialyzer {:no_unused, {:maybe_validate_user, 1}}

  require Logger

  use BorutaAdminWeb, :controller

  alias Boruta.Oauth.Authorization
  alias BorutaAdminWeb.ErrorView

  def require_authenticated(conn, _opts \\ []) do
    with [authorization_header] <- get_req_header(conn, "authorization"),
         [_authorization_header, token] <- Regex.run(~r/Bearer (.+)/, authorization_header),
         {:ok, token} <- Authorization.AccessToken.authorize(value: token) do
      conn
      |> assign(:token, token)
      |> assign(:introspected_token, %{
        "sub" => token.sub,
        "active" => true,
        "scope" => token.scope
      })
    else
      {:error, _error} ->
        with [authorization_header] <- get_req_header(conn, "authorization"),
             [_authorization_header, token] <- Regex.run(~r/Bearer (.+)/, authorization_header),
             {:ok, %{"sub" => sub, "active" => true} = payload} <- introspect(token),
             :ok <- maybe_validate_user(sub) do
          conn
          |> assign(:token, token)
          |> assign(:introspected_token, payload)
        else
          e ->
            unauthorized(conn, e)
        end

      e ->
        unauthorized(conn, e)
    end
  end

  def authorize(conn, [_h | _t] = scopes) do
    current_scopes = String.split(conn.assigns[:introspected_token]["scope"], " ")

    case Enum.empty?(scopes -- current_scopes) do
      true ->
        conn

      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
        |> halt()
    end
  end

  def authorize(conn, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(ErrorView)
    |> render("403.json")
    |> halt()
  end

  # TODO cache token introspection
  def introspect(token) do
    oauth2_config = Application.get_env(:boruta_web, BorutaAdminWeb.Authorization)[:oauth2]
    client_id = oauth2_config[:client_id]
    client_secret = oauth2_config[:client_secret]
    site = oauth2_config[:site]

    with {:ok, %Finch.Response{body: body}} <-
           Finch.build(
             :post,
             "#{site}/oauth/introspect",
             [
               {"accept", "application/json"},
               {"content-type", "application/x-www-form-urlencoded"},
               {"authorization", "Basic " <> Base.encode64("#{client_id}:#{client_secret}")}
             ],
             URI.encode_query(%{token: token})
           )
           |> Finch.request(FinchHttp) do
      Jason.decode(body)
    end
  end

  defp unauthorized(conn, e) do
    Logger.debug("User unauthorized : #{inspect(e)}")

    conn
    |> put_status(:unauthorized)
    |> put_view(ErrorView)
    |> render("401.json")
    |> halt()
  end

  defp maybe_validate_user(sub) do
    case Application.get_env(:boruta_web, BorutaAdminWeb.Authorization)[:sub_restricted] do
      nil ->
        :ok

      restricted_sub ->
        case sub do
          ^restricted_sub ->
            :ok

          _ ->
            {:error, "Instance management is restricted to #{restricted_sub}"}
        end
    end
  end
end
