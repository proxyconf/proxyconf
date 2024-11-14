defmodule ProxyConfWeb.Router do
  use ProxyConfWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ProxyConfWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json", "yaml", "octet-stream"]
  end

  scope "/api", ProxyConfWeb do
    pipe_through :api
    post "/upload/:spec_name", ApiController, :upload_spec
    post "/upload_bundle/:cluster_id", ApiController, :upload_bundle
  end

  scope "/", ProxyConfWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ProxyConfWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:proxyconf, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ProxyConfWeb.Telemetry
    end
  end
end
