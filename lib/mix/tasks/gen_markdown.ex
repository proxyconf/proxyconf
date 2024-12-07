defmodule Mix.Tasks.GenMarkdown do
  @moduledoc """
    Generates markdown documents from Jsonschema Input

    To generate ProxyConf documentation one should execute this task
    as follows:

      mix gen_markdow

  """
  @shortdoc "JsonSchema to Markdown"

  use Mix.Task
  @requirements ["app.config"]

  @impl Mix.Task
  def run([]) do
    schema =
      GenJsonSchema.gen(ProxyConf.Spec, :root, case: :to_kebab)
      |> Jason.encode!(pretty: true)

    %JsonXema{} = JsonXema.new(Jason.decode!(schema))

    File.write!(Path.join([:code.priv_dir(:proxyconf), "schemas", "proxyconf.json"]), schema)
    schema = Jason.decode!(schema)

    to_md("config", schema, Map.get(schema, "definitions", %{}))
    hurl_examples_to_md()
  end

  @templatevars %{~c"envoy-cluster" => "demo"}

  def hurl_examples_to_md do
    Path.wildcard("examples/*.yaml")
    |> Enum.flat_map(fn example ->
      case File.read!(example)
           |> :bbmustache.render(@templatevars)
           |> YamlElixir.read_from_string!() do
        %{"openapi" => _, "info" => %{"title" => title} = info} = spec ->
          summary = Map.get(info, "summary", "no-category")

          {hurl, 0} =
            System.cmd("hurlfmt", ["--out", "html", String.replace(example, ".yaml", ".hurl")])

          doc = """
          ## #{title}


          #{Map.get(info, "description", "")}

          ```yaml title="OpenAPI Specification"
          #{Ymlr.document!(Map.put(spec, "info", %{"title" => title})) |> String.replace_prefix("---\n", "")}
          ```

          <h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
          <div class="hurl">#{hurl}</div>
          """

          [{summary, doc}]

        _ ->
          []
      end
    end)
    |> Enum.group_by(fn {summary, _} -> summary end, fn {_, doc} -> doc end)
    |> Map.delete("no-category")
    |> Enum.each(fn {summary, docs} ->
      file_name = Recase.to_kebab(summary)
      File.write!("docs/examples/#{file_name}.md", ["# #{summary}" | docs] |> Enum.join("\n"))
    end)
  end

  @out "docs/config"
  defp to_md(root_schema_name, schema, defs) do
    md = to_md_(root_schema_name, schema, 0, defs, []) |> Enum.reverse()
    md = Enum.join(md, "\n")
    name = Path.join(@out, "#{root_schema_name}.md")
    File.write!(name, md)
  end

  defp to_md_(current_prop_name, %{"type" => "object"} = schema, level, defs, acc)
       when is_map(schema) do
    properties =
      Map.get(schema, "properties", %{})
      |> Map.merge(
        case Map.get(schema, "additionalProperties") do
          %{} = ap -> %{"additional property" => ap}
          _ -> %{}
        end
      )

    acc = [
      md_title_and_description(current_prop_name, schema, level, defs)
      | acc
    ]

    Enum.reduce(properties, acc, fn {prop_name, prop}, acc ->
      to_md_(prop_name, prop, level + 1, defs, acc)
    end)
  end

  defp to_md_(current_prop_name, %{"type" => "array"} = schema, level, defs, acc)
       when is_map(schema) do
    [
      md_title_and_description(current_prop_name, schema, level, defs)
      | acc
    ]
  end

  defp to_md_(current_prop_name, %{"oneOf" => items} = schema, level, defs, acc) do
    acc =
      [
        md_title_and_description(current_prop_name, schema, level, defs)
        | acc
      ]

    Enum.reduce(items, acc, fn i, acc ->
      to_md_(
        current_prop_name,
        i |> Map.put("x-option-for", current_prop_name),
        level + 1,
        defs,
        acc
      )
    end)
  end

  defp to_md_(
         current_prop_name,
         %{"$ref" => "#/definitions/Elixir." <> module} = schema,
         level,
         defs,
         acc
       ) do
    new_root =
      String.split(module, ".")
      |> List.last()
      |> String.split("_")
      |> List.first()

    remote_schema = Map.fetch!(defs, "Elixir." <> module)
    to_md(new_root, remote_schema, defs)

    [
      md_title_and_description(
        current_prop_name,
        schema
        |> Map.merge(remote_schema |> Map.take(["title", "description"])),
        level,
        defs
      )
      | acc
    ]
  end

  defp to_md_(
         current_prop_name,
         %{"title" => _, "$ref" => "#/definitions/" <> local_def} = schema,
         level,
         defs,
         acc
       ) do
    def = Map.fetch!(defs, local_def)

    acc = [
      md_title_and_description(
        current_prop_name,
        schema,
        level,
        defs
      )
      | acc
    ]

    to_md_(current_prop_name, def, level + 1, defs, acc)
  end

  defp to_md_(current_prop_name, %{"$ref" => "#/definitions/" <> name} = schema, level, defs, acc) do
    to_md_(
      current_prop_name,
      Map.fetch!(defs, name)
      |> Map.merge(Map.take(schema, ["x-option-for"])),
      level,
      defs,
      acc
    )
  end

  defp to_md_(current_prop_name, %{"$ref" => "file:" <> _name} = schema, level, defs, acc) do
    [md_title_and_description(current_prop_name, schema, level, defs) | acc]
  end

  defp to_md_(prop_name, schema, level, defs, acc) do
    [md_title_and_description(prop_name, schema, level, defs) | acc]
  end

  defp md_title_and_description(prop_name, schema, level, defs) when is_map(schema) do
    title = Map.get(schema, "title", "")
    description = Map.get(schema, "description", "")

    [
      "\n",
      "#{Enum.map(0..level, fn _ -> "#" end)} #{title}",
      "\n\n",
      md_table(prop_name, schema, defs),
      "\n",
      description,
      "\n",
      md_example(schema)
    ]
  end

  defp type(schema, defs) do
    type = Map.get(schema, "type")
    const? = Map.has_key?(schema, "const")
    remote? = Map.has_key?(schema, "$ref")
    oneOf = Map.has_key?(schema, "oneOf")
    oneOfOption? = Map.has_key?(schema, "x-option-for")

    cond do
      oneOf ->
        "choice"

      oneOfOption? and const? ->
        "option #{Map.get(schema, "const")}"

      oneOfOption? ->
        "option #{type}"

      const? ->
        "constant #{Map.get(schema, "const")}"

      remote? ->
        %{"$ref" => "#/definitions/" <> ref} = schema
        schema = Map.fetch!(defs, ref)
        type(schema, defs)

      true ->
        type
    end
  end

  defp md_table(prop_name, schema, defs) when is_map(schema) do
    table_rows =
      Map.drop(schema, [
        "$id",
        "title",
        "type",
        "description",
        "examples",
        "x-option-for"
      ])
      |> Enum.flat_map(fn
        {"oneOf", schemas} ->
          schemas =
            Enum.map(schemas, fn
              %{"title" => _title} = s ->
                "<li>#{md_link(s, defs)}</li>"

              %{"$ref" => "#/definitions/" <> ref} ->
                schema = Map.fetch!(defs, ref)
                "<li>#{md_link(schema, defs)}</li>"

              _ ->
                "<li>TODO: Untitled OneOf</li>"
            end)

          ["| **options** | <ul>#{schemas}</ul> |\n"]

        {"properties", properties} when map_size(properties) > 0 ->
          links =
            Enum.map(properties, fn {k, s} ->
              md_link(s, defs, "`#{k}`")
            end)

          ["| **properties** | #{Enum.join(links, ", ")} |\n"]

        {"properties", _} ->
          []

        {"required", required_properties} when is_list(required_properties) ->
          links =
            Map.get(schema, "properties", %{})
            |> Enum.reject(fn {k, _s} -> k in required_properties end)
            |> Enum.map(fn {k, s} ->
              md_link(s, defs, "`#{k}`")
            end)

          if links == [] do
            []
          else
            ["| **optional** | #{Enum.join(links, ", ")} |\n"]
          end

        {"additionalProperties", v} when is_map(v) ->
          generic_property_type =
            case v do
              %{"type" => t} ->
                "`#{t}`"

              %{"$ref" => _ref} = s ->
                md_link(s, defs)
            end

          ["| **generic properties** | #{generic_property_type} |\n"]

        {"items", schema} ->
          item_type =
            case schema do
              %{"type" => t} ->
                t

              %{"$ref" => ref} ->
                ref
            end

          ["| **Array Item** | #{md_table("", item_type, defs)} |\n"]

        {"$ref", "#/definitions/" <> ref} ->
          schema = Map.fetch!(defs, ref)
          ["| **$ref** | #{md_link(schema, defs)} |\n"]

        {k, v} when not is_map(v) ->
          ["| **#{k}** | #{md_table("", v, defs)} |\n"]

        _ ->
          []
      end)

    type = type(schema, defs)

    case type do
      "constant " <> const ->
        "<table><tr><th>Constant</th><th><code>#{const} <i>(string)</i></code></th></tr></table>"

      "option " <> type when type not in ["object"] ->
        "<table><tr><th>Choice Option</th><th><code>#{prop_name} <i>(#{type})</i></code></th></tr></table>"

      "option " <> type ->
        [
          "| Choice Option | `#{prop_name}` *`(#{type})`* |\n | --- | --- |\n"
          | table_rows
        ]

      type when prop_name == "additional property" ->
        [
          "| Generic Property | *`#{type}`* |\n | --- | --- |\n"
          | table_rows
        ]

      type ->
        [
          "| Property | `#{prop_name}` *`(#{type})`* |\n | --- | --- |\n"
          | table_rows
        ]
    end
  end

  defp md_table(prop_name, list, defs) when is_list(list) do
    Enum.map(list, fn e ->
      "#{md_table(prop_name, e, defs)}"
    end)
    |> Enum.join(", ")
  end

  defp md_table(_, e, _defs) do
    "`#{e}`"
  end

  defp md_example(schema) when is_map(schema) do
    examples = Map.get(schema, "examples", [])

    if examples == [] do
      []
    else
      Enum.map(examples, fn example ->
        """
        ```yaml title="Example"
        #{Ymlr.document!(example) |> String.replace_prefix("---\n", "")}
        ```
        """
      end)
    end
  end

  defp md_link(schema, defs, name \\ nil)

  @splitter ~r/[[:punct:]|[:space:]]/
  defp md_link(%{"title" => title} = _schema, _defs, name) do
    link =
      Regex.split(@splitter, title)
      |> Enum.reject(fn s -> s == "" end)
      |> Enum.join("-")
      |> String.downcase()

    "[#{name || title}](##{link})"
  end

  defp md_link(%{"$ref" => "#/definitions/" <> ref}, defs, name) do
    schema = Map.fetch!(defs, ref)
    md_link(schema, defs, name)
  end
end
