defmodule CaloriWeb.PageController do
  use CaloriWeb, :controller

  def home(conn, _params) do
    # redirect to the default page, e. g., home or login
    conn
    |> redirect(to: ~p"/home")
  end
end
