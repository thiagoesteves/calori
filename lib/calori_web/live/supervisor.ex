defmodule CaloriWeb.SupervisorLive do
  use CaloriWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- <div class="min-h-screen bg-gray-700 flex flex-col items-center justify-center">
      <h1 class="text-5xl text-white font-bold mb-8 animate-pulse">
        Coming Soon
      </h1>
      <p class="text-white text-lg mb-8">
        We're working hard to bring you something amazing. Stay tuned!
      </p>
    </div> --%>

    <div class=" flex min-h-screen bg-gray-100 rounded-b-lg ">
      <div class="container mt-5  mx-auto md:px-6 ">
        <section class="mb-32">
          <div class="flex flex-wrap">
            <div class="w-full shrink-0 grow-0 basis-auto md:w-3/12 lg:w-4/12">
              <img
                src={~p"/images/supervisor.png"}
                class="mb-6 w-full rounded-lg shadow-lg dark:shadow-black/20"
                alt="Avatar"
              />
            </div>

            <div class="w-full shrink-0 grow-0 basis-auto text-center md:w-9/12 md:pl-6 md:text-left lg:w-8/12">
              <h5 class="mb-6 text-xl font-semibold">Who supervises the application?</h5>
              <p>
                <u><a href="https://calori.com.br/">Calori Software</a></u>
                webserver was created using the Erlang Beam VM and the <u><a href="https://www.phoenixframework.org/">Phoenix Liveview Framework</a></u>.
                Its source code and all deployment configurations are available at this <u><a href="https://github.com/thiagoesteves/calori">repository</a></u>.
                This webserver is also supervised by <u><a href="https://github.com/thiagoesteves/deployex">Deployex</a></u>,
                another Phoenix LiveView application specifically designed for supervising Elixir applications. If you want to check real time deployments within calori webserver, just <u><a href="https://deployex.calori.com.br/">click here</a></u>.
              </p>
            </div>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
