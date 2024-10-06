defmodule Mix.Tasks.GenMarkdown do
  @moduledoc """
    Generates markdown documents from Jsonschema Input

    To generate ProxyConf documentation one should execute this task
    as follows:

      mix gen_markdown priv/schemas/config docs/config

  """
  @shortdoc "JsonSchema to Markdown"

  use Mix.Task
  @requirements ["app.config"]

  @impl Mix.Task
  def run([jsonschema_path, out_path]) do
    Path.wildcard(Path.join(jsonschema_path, "/**/*.json"))
    |> Enum.each(fn p ->
      try do
        Process.put(:schema_file, p)
        schema = File.read!(p) |> Jason.decode!()
        name = String.replace_prefix(p, jsonschema_path, out_path)
        name = name <> ".md"
        md = to_md_("root", schema, 0, []) |> Enum.reverse()
        md = Enum.join(md, "\n")
        File.mkdir_p!(Path.dirname(name))
        File.write!(name, md)
      rescue
        e ->
          IO.puts("Error generating markdown from #{p} due to #{Exception.message(e)}")
          :ok
      end
    end)
  end

  defp to_md_(current_prop_name, %{"type" => "object"} = schema, level, acc)
       when is_map(schema) do
    properties = Map.get(schema, "properties", %{})

    acc = [
      md_title_and_description(current_prop_name, schema, level)
      | acc
    ]

    Enum.reduce(properties, acc, fn {prop_name, prop}, acc ->
      to_md_(prop_name, prop, level + 1, acc)
    end)
  end

  defp to_md_(current_prop_name, %{"type" => "array"} = schema, level, acc)
       when is_map(schema) do
    items = Map.get(schema, "items", %{})

    acc = [
      md_title_and_description(current_prop_name, schema, level)
      | acc
    ]

    to_md_("Array Item", items, level + 1, acc)
  end

  defp to_md_(current_prop_name, %{"oneOf" => items} = schema, level, acc) do
    acc =
      [
        md_title_and_description(current_prop_name, schema, level)
        | acc
      ]

    Enum.reduce(items, acc, fn i, acc ->
      to_md_(current_prop_name, i, level + 1, acc)
    end)
  end

  defp to_md_(current_prop_name, %{"$ref" => "file:" <> _name} = schema, level, acc) do
    [md_title_and_description(current_prop_name, schema, level) | acc]
  end

  defp to_md_(prop_name, schema, level, acc) do
    [md_title_and_description(prop_name, schema, level) | acc]
  end

  require Logger

  defp md_title_and_description(prop_name, schema, level) when is_map(schema) do
    title = Map.get(schema, "title", "")
    description = Map.get(schema, "description", "")

    if title == "" do
      Logger.warning("#{Process.get(:schema_file)}:#{prop_name} missing title")
    end

    if description == "" do
      Logger.warning("#{Process.get(:schema_file)}: #{prop_name} missing description")
    end

    [
      "\n",
      "#{Enum.map(0..level, fn _ -> "#" end)} #{title}",
      "\n\n",
      md_table(prop_name, schema),
      "\n",
      md_example(schema),
      description
    ]
  end

  defp md_table(prop_name, schema) when is_map(schema) do
    table_rows =
      Map.drop(schema, [
        "$id",
        "title",
        "type",
        "description",
        "examples",
        "additional_properties"
      ])
      |> Enum.flat_map(fn
        {"$ref", "file://" <> file_ref} ->
          link_name = Map.get(schema, "title", file_ref)
          ["| **$ref** | <a href=\"/#{file_ref}\">#{link_name}</a> |\n"]

        {"oneOf", schemas} ->
          schemas =
            Enum.map(schemas, fn schema ->
              "<tr><td>#{Map.get(schema, "title", "TODO: Untitled OneOf")}</td></tr>"
            end)

          ["| **oneOf** | <table>#{schemas}</table> |\n"]

        {"properties", properties} ->
          ["| **properties** | #{md_table("", Map.keys(properties))} |\n"]

        {k, v} when not is_map(v) ->
          ["| **#{k}** | #{md_table("", v)} |\n"]

        _ ->
          []
      end)

    if table_rows == [] do
      []
    else
      type = Map.get(schema, "type")
      const? = Map.has_key?(schema, "const")
      oneOf? = Map.has_key?(schema, "oneOf")
      object? = Map.has_key?(schema, "object")

      cond do
        object? ->
          ["| *`#{type}`* with the following constraints: |   |\n | --- | --- |\n" | table_rows]

        oneOf? ->
          [
            "|  |  |\n | --- | --- |\n"
            | table_rows
          ]

        const? ->
          "<table><tr><th>Constant</th><th><code>#{Map.get(schema, "const")} <i>(string)</i></code></th></tr></table>"

        true ->
          [
            "| Property | `#{prop_name}` *`(#{type})`* |\n | --- | --- |\n"
            | table_rows
          ]
      end
    end
  end

  defp md_table(prop_name, list) when is_list(list) do
    Enum.map(list, fn e ->
      "#{md_table(prop_name, e)}"
    end)
    |> Enum.join(", ")
  end

  defp md_table(_, e) do
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
end
