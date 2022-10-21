defmodule OasWeb.Router do
  use OasWeb, :router

  import OasWeb.MemberAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {OasWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_member
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OasWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", OasWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OasWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", OasWeb do
    pipe_through [:browser, :redirect_if_member_is_authenticated]

    get "/members/register", MemberRegistrationController, :new
    post "/members/register", MemberRegistrationController, :create
    get "/members/log_in", MemberSessionController, :new
    post "/members/log_in", MemberSessionController, :create
    get "/members/reset_password", MemberResetPasswordController, :new
    post "/members/reset_password", MemberResetPasswordController, :create
    get "/members/reset_password/:token", MemberResetPasswordController, :edit
    put "/members/reset_password/:token", MemberResetPasswordController, :update
  end

  scope "/", OasWeb do
    pipe_through [:browser, :require_authenticated_member]

    get "/members/settings", MemberSettingsController, :edit
    put "/members/settings", MemberSettingsController, :update
    get "/members/settings/confirm_email/:token", MemberSettingsController, :confirm_email
  end

  scope "/", OasWeb do
    pipe_through [:browser]

    delete "/members/log_out", MemberSessionController, :delete
    get "/members/log_out", MemberSessionController, :delete
    get "/members/confirm", MemberConfirmationController, :new
    post "/members/confirm", MemberConfirmationController, :create
    get "/members/confirm/:token", MemberConfirmationController, :edit
    post "/members/confirm/:token", MemberConfirmationController, :update
  end

  pipeline :graphql do
    plug :fetch_session
    plug OasWeb.Context
  end

  scope "/api" do
    pipe_through :graphql

    forward "/graphql", Absinthe.Plug,
      schema: OasWeb.Schema
    
    forward "/graphiql",
      Absinthe.Plug.GraphiQL,
      schema: OasWeb.Schema,
      # interface: :simple,
      default_url: "http://localhost:4000/graphql"
  end

end
