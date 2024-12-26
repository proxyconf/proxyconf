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

  pipeline :authenticated_api do
    plug :accepts, ["json", "yaml", "octet-stream"]
    plug ExOauth2Provider.Plug.VerifyHeader, otp_app: :proxyconf, realm: "Bearer"
    plug ExOauth2Provider.Plug.EnsureAuthenticated
    plug ExOauth2Provider.Plug.EnsureScopes, scopes: ~w(cluster-admin)
  end

  scope "/api", ProxyConfWeb do
    pipe_through :authenticated_api
    get "/spec/:spec_name", ApiController, :get_spec
    delete "/spec/:spec_name", ApiController, :delete_spec
    post "/spec/:spec_name", ApiController, :upload_spec
    get "/specs", ApiController, :get_specs
    post "/upload_bundle", ApiController, :upload_bundle
    post "/secret/:secret_name", ApiController, :create_or_update_secret
    post "/rotate-client-secret", OAuthController, :rotate_cluster_secret
  end

  scope "/api", ProxyConfWeb do
    pipe_through :api
    post "/create-config/:cluster_name", OAuthController, :create_cluster
    post "/access-token", OAuthController, :issue_token
    get "/jwks.json", OAuthController, :jwks
    match :*, "/echo/*echo", ApiController, :echo
  end

  scope "/" do
    pipe_through :browser
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
