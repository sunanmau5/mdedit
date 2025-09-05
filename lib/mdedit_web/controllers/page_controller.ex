defmodule MdeditWeb.PageController do
  use MdeditWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
