defmodule ProxyConf.CLI do
  @moduledoc """
  Documentation for `ProxyConf.CLI`.
  """

  alias ProxyConf.Commons.ConfigGenerator
  alias ProxyConf.Commons.Spec

  @doc """
  Hello world.

  ## Examples

      iex> ProxyConf.CLI.hello()
      :world

  """
  def hello do
    :world
  end

  defp optimus,
    do:
      Optimus.new!(
        name: "proxyconf",
        description: "ProxyConf for the Command Line",
        version: "0.0.1",
        author: "André Graf",
        about: "Utility for interacting with ProxyConf Envoy Control Plane",
        allow_unknown_args: false,
        parse_double_dash: true,
        subcommands: [
          maintenance: [
            name: "maintenance",
            about: "Maintenance commands",
            args: [
              command: [
                value_name: "COMMAND",
                required: true
              ]
            ]
          ],
          static: [
            name: "static",
            about:
              "Generates an Envoy Configuration that only uses static resources. This enables simple testing without a ProxyConf Control Plane deployment. For static generation the secret discovery relies on files that contain the secret values (e.g. TLS certificates/private keys or upstream credentials).",
            args: [
              input_dir: [
                value_name: "INPUT",
                short: "-i",
                long: "--input-dir",
                help: "Input directory containing the OpenAPI specifications",
                parser: fn p ->
                  if File.dir?(p) do
                    {:ok, p}
                  else
                    {:error, "invalid input directory"}
                  end
                end,
                required: true
              ],
              output: [
                value_name: "OUTPUT",
                short: "-o",
                long: "--output",
                help: "Output config file",
                parser: fn p ->
                  if File.dir?(Path.dirname(p)) do
                    {:ok, p}
                  else
                    {:error, "output directory does not exist"}
                  end
                end,
                required: true
              ]
            ],
            options: [
              cluster_id: [
                value_name: "CLUSTER",
                short: "-c",
                long: "--cluster-id",
                help: "Envoy Service Cluster Id",
                parser: :string,
                default: "proxyconf-static"
              ],
              template_vars: [
                value_name: "TEMPLATE_VARS",
                short: "-t",
                long: "--template-var",
                help:
                  "Template variable used to fill mustache template variable in OpenAPI specifications",
                parser: fn tv ->
                  case String.split(tv, "=") do
                    [k, v] ->
                      {:ok, {String.trim(k) |> String.to_charlist(), String.trim(v)}}

                    _ ->
                      {:error, "Invalid template variable #{tv}"}
                  end
                end,
                multiple: true,
                default: [],
                required: false
              ]
            ]
          ]
        ]
      )

  def parse_argv!(argv) do
    Optimus.parse!(optimus(), argv)
  end

  def parse_argv(argv) do
    Optimus.parse(optimus(), argv)
  end

  def start(_type, _args) do
    parse_result =
      Burrito.Util.Args.argv() |> parse_argv!()

    case parse_result do
      %Optimus.ParseResult{} ->
        Optimus.help(optimus())
        |> IO.puts()

        System.halt(1)

      {[:static], %Optimus.ParseResult{args: args, options: options}} ->
        case path_to_specs(args.input_dir, options.cluster_id, options.template_vars) do
          {:ok, specs} ->
            config =
              ConfigGenerator.static_config_generation(specs)

            File.write!(args.output, config)
            System.halt(0)

          {:error, errors} ->
            Enum.each(errors, fn {filename, error} ->
              IO.puts("Error #{filename}: #{error}")
            end)

            System.halt(1)
        end
    end
  end

  def path_to_specs(path, cluster_id, template_vars) do
    case iterate_directory_contents(path, cluster_id, template_vars) do
      {specs, []} ->
        {:ok, specs}

      {_, errors} ->
        {:error, errors}
    end
  end

  defp iterate_directory_contents(path, cluster_id, template_vars) do
    directory_spec_provider = fn iterator_fn, iterator_acc ->
      File.ls!(path)
      |> Enum.reject(&File.dir?/1)
      |> Enum.reduce(iterator_acc, fn f, acc ->
        iterator_fn.(f, fn -> File.read!(Path.join(path, f)) end, acc)
      end)
    end

    Spec.to_specs(directory_spec_provider, cluster_id, template_vars)
  end
end
