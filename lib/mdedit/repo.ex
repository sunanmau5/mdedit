defmodule Mdedit.Repo do
  use Ecto.Repo,
    otp_app: :mdedit,
    adapter: Ecto.Adapters.Postgres
end
