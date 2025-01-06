[
  import_deps: [:phoenix, :ecto],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{apps,config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
