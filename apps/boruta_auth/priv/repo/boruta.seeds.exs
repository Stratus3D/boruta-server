import Ecto.Changeset

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "scopes:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "clients:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "upstreams:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "users:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "identity-providers:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "instances:manage:user"
  },
  on_conflict: :nothing
)

{:ok, client} = Boruta.Ecto.Admin.create_client(%{
  secret: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", "777"),
  id: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20"),
  redirect_uris: [
    "#{System.get_env("BORUTA_ADMIN_BASE_URL", "http://localhost:4002")}/oauth-callback"
  ],
  access_token_ttl: 3600,
  authorization_code_ttl: 60,
  authorize_scope: true,
  authorized_scopes: BorutaAuth.Repo.all(Boruta.Ecto.Scope) |> Enum.map(&Map.from_struct/1)
})

{:ok, identity_provider} = BorutaIdentity.IdentityProviders.create_identity_provider(%{
  name: "Default",
  registrable: true
})

BorutaIdentity.IdentityProviders.upsert_client_identity_provider(client.id, identity_provider.id)

{:ok, user} = BorutaIdentity.Accounts.Internal.User.registration_changeset(%BorutaIdentity.Accounts.Internal.User{}, %{
  email: System.get_env("BORUTA_ADMIN_EMAIL", "test@test.test"),
  password: System.get_env("BORUTA_ADMIN_PASSWORD", "passwordesat"),
  password_confirmation: System.get_env("BORUTA_ADMIN_PASSWORD", "passwordesat")
}) |> BorutaIdentity.Repo.insert()

user = BorutaIdentity.Accounts.Internal.domain_user!(user)

Boruta.Ecto.Admin.get_scopes_by_names([
  "users:manage:all",
  "clients:manage:all",
  "scopes:manage:all",
  "upstreams:manage:all",
  "identity-providers:manage:all",
  "instances:manage:user"
])
|> Enum.map(fn %{id: scope_id} ->
  BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{
    scope_id: scope_id,
    user_id: user.id
  })
end)
