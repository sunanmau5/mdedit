defmodule MdeditWeb.Presence do
  @moduledoc """
  Provides presence tracking to see who's currently online.
  """
  use Phoenix.Presence,
    otp_app: :mdedit,
    pubsub_server: Mdedit.PubSub
end
