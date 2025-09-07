defmodule MdeditWeb.PageControllerTest do
  use MdeditWeb.ConnCase

  test "GET / (LiveView)", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Collaborative"
    assert html_response(conn, 200) =~ "Markdown"
    assert html_response(conn, 200) =~ "Editor"
  end
end
