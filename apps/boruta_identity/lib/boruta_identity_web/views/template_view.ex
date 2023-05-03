defmodule BorutaIdentityWeb.TemplateView do
  use BorutaIdentityWeb, :view

  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentityWeb.ErrorHelpers

  def render("template.html", %{
        conn: conn,
        template: %Template{
          layout: layout,
          content: content,
          identity_provider: identity_provider
        },
        assigns: assigns
      }) do
    context =
      context(%{conn: conn}, Map.put(assigns, :identity_provider, identity_provider))
      |> Map.put(:messages, messages(conn))
      |> Map.put(:_csrf_token, Plug.CSRFProtection.get_csrf_token())
      |> Map.merge(errors(assigns))
      |> Map.merge(paths(conn, assigns))
      |> Map.merge(identity_provider_configurations(identity_provider))

    {:safe, Mustachex.render(layout.content, context, partials: %{inner_content: content})}
  end

  def context(%{conn: conn} = context, %{identity_provider: identity_provider} = assigns) do
    %Plug.Conn{query_params: query_params} = conn
    request = Map.get(query_params, "request")
    backend = identity_provider.backend

    federated_servers =
      Enum.map(backend.federated_servers, fn federated_server ->
        federated_server_name = federated_server["name"]

        {federated_server_name,
         %{login_url: Routes.backends_path(BorutaIdentityWeb.Endpoint, :authorize, backend.id, federated_server_name, %{request: request})}}
      end)
      |> Enum.into(%{})

    %{federated_servers: federated_servers}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :identity_provider))
  end

  def context(context, %{current_user: current_user} = assigns) do
    current_user = Map.from_struct(current_user)

    %{current_user: current_user}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :current_user))
  end

  def context(context, %{client: client} = assigns) do
    client = Map.from_struct(client)

    %{client: client}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :client))
  end

  def context(context, %{scopes: scopes} = assigns) do
    scopes = Enum.map(scopes, &Map.from_struct/1)

    %{scopes: scopes}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :scopes))
  end

  def context(context, %{}), do: context

  defp paths(conn, assigns) do
    %Plug.Conn{query_params: query_params} = conn
    request = Map.get(query_params, "request")

    %{
      boruta_logo_path: Routes.static_path(BorutaIdentityWeb.Endpoint, "/images/logo-yellow.png"),
      choose_session_path:
        Routes.choose_session_path(BorutaIdentityWeb.Endpoint, :index, %{request: request}),
      create_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_confirmation_path:
        Routes.user_confirmation_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_consent_path: Routes.user_consent_path(conn, :consent, %{request: request}),
      create_user_registration_path:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      delete_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{request: request}),
      edit_user_path:
        Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :edit, %{request: request}),
      new_user_registration_path:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      new_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      new_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      update_user_reset_password_path:
        Routes.user_reset_password_path(
          BorutaIdentityWeb.Endpoint,
          :update,
          Map.get(assigns, :token, ""),
          %{request: request}
        ),
      update_user_path:
        Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :update, %{request: request})
    }
  end

  defp errors(%{errors: errors}) do
    formatted_errors = Enum.map(errors, &%{message: &1})

    %{valid?: false, errors: formatted_errors}
  end

  defp errors(%{changeset: changeset}) do
    formatted_errors =
      changeset
      |> ErrorHelpers.error_messages()
      |> Enum.map(fn message -> %{message: message} end)

    %{valid?: false, errors: formatted_errors}
  end

  defp errors(_assigns), do: %{errors: [], valid?: true}

  defp messages(conn) do
    get_flash(conn)
    |> Enum.map(fn {type, value} ->
      %{
        "type" => type,
        "content" => value
      }
    end)
  end

  defp identity_provider_configurations(identity_provider) do
    %{
      registrable?: identity_provider.registrable,
      user_editable?: identity_provider.user_editable
    }
  end
end
