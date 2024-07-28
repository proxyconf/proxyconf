defmodule ProxyConf.MapTemplate do
  @moduledoc """

  Map based templates. Type of keys can be any term,
  but if a value type is an atom, the atom is treated as
  a variale that must be provided in an 'assigns' map when
  the template is evaluated.

  iex> # template with two variables, :stuff and :bye
  ...> defmodule SubTemplate do
  ...>  use ProxyConf.MapTemplate
  ...>  deftemplate(%{cool: :stuff, is: [%{good: :bye}, :hello]})
  ...> end
  ...>
  ...> # template with one variable, SubTemplate
  ...> defmodule MainTemplate do
  ...>   use ProxyConf.MapTemplate
  ...>   deftemplate(%{hello: "world", nana: SubTemplate})
  ...> end
  ...>
  ...> # evaluating the template 
  ...> MainTemplate.eval(%{stuff: 100, bye: "nice", hello: ["nested", "list"]})
  %{hello: "world", nana: %{cool: 100, is: [%{good: "nice"}, "nested", "list"]}}
  """

  # @derive {Inspect, only: [:template]}
  defstruct [:line, :module, :template, :markers, :template_hash]

  defmacro deftemplate(data) do
    quote do
      @map_template template(unquote(data)) |> Map.merge(Map.take(__ENV__, [:line, :module]))

      def eval(assigns) do
        eval(@map_template, assigns)
      end

      def __map_template__ do
        @map_template
      end
    end
  end

  def template(data) do
    {template, markers} = to_template(data, %{})
    hash = :crypto.hash(:sha256, :erlang.term_to_binary(template))

    %ProxyConf.MapTemplate{
      line: __ENV__.line,
      module: __ENV__.module,
      template: template,
      markers: markers,
      template_hash: hash
    }
  end

  def eval(%__MODULE__{} = template, assigns) do
    {result, _} = eval(template, assigns, [])
    result
  end

  defmacro __using__(_opts) do
    quote do
      import ProxyConf.MapTemplate
      require ProxyConf.MapTemplate
    end
  end

  def to_template(data, acc, path \\ [])

  def to_template(data, acc, path) when is_list(data) do
    Enum.map_reduce(Enum.zip(0..(length(data) - 1), data), acc, fn {idx, f}, acc ->
      to_template(f, acc, [idx | path])
    end)
  end

  def to_template(%__MODULE__{} = subtemplate, acc, path) do
    path = Enum.reverse(path)
    {subtemplate, Map.put(acc, path, subtemplate)}
  end

  def to_template(data, acc, path) when is_map(data) do
    {data, acc} =
      Enum.map_reduce(data, acc, fn {k, v}, acc ->
        {v, acc} = to_template(v, acc, [k | path])
        {{k, v}, acc}
      end)

    {Map.new(data), acc}
  end

  def to_template(bool, acc, _path) when is_boolean(bool) do
    {bool, acc}
  end

  def to_template(atom, acc, path) when is_atom(atom) do
    path = Enum.reverse(path)

    value =
      if function_exported?(atom, :__map_template__, 0) do
        atom.__map_template__()
      else
        atom
      end

    {value, Map.put(acc, path, value)}
  end

  def to_template(data, acc, _path) do
    {data, acc}
  end

  def upd_in(data, [p], value) when is_map(data) do
    Map.replace!(data, p, value)
  end

  # special case where we want to flatten the resulting list
  def upd_in(data, [p], value) when is_list(data) and is_list(value) and is_integer(p) do
    List.replace_at(data, p, value) |> List.flatten()
  end

  def upd_in(data, [p], value) when is_list(data) and is_integer(p) do
    List.replace_at(data, p, value)
  end

  def upd_in(data, [p | path], value) when is_map(data) do
    Map.put(data, p, upd_in(Map.fetch!(data, p), path, value))
  end

  def upd_in(data, [p | path], value) when is_list(data) and is_integer(p) do
    List.replace_at(data, p, upd_in(Enum.at(data, p), path, value))
  end

  def upd_in(data, [p | path], value) when is_list(data) and is_integer(p) do
    List.replace_at(data, p, upd_in(Enum.at(data, p), path, value))
  end

  def eval(
        %__MODULE__{
          template: template,
          markers: markers,
          template_hash: _template_hash,
          module: module,
          line: line
        },
        assigns,
        processed_templates
      ) do
    Enum.reduce(markers, {template, processed_templates}, fn
      {marker, %__MODULE__{} = subtemplate}, {acc_template, acc_processed_templates} ->
        {replacement, acc_processed_templates} =
          eval(subtemplate, assigns, acc_processed_templates)

        {upd_in(acc_template, marker, replacement), acc_processed_templates}

      {marker, assign}, {acc_template, acc_processed_templates} ->
        {replacement, acc_processed_templates} =
          case Map.get(assigns, assign, {:error, :not_found}) do
            {:error, :not_found} ->
              raise(
                "Missing assign :#{assign} required by template defined in #{module} on line #{line}"
              )

            %__MODULE__{template_hash: template_hash} = injected_template ->
              if template_hash in processed_templates do
                raise(
                  "Circular subtemplating detected in injected template defined in #{injected_template.module} on line #{injected_template.line}"
                )
              else
                eval(injected_template, assigns, [template_hash | acc_processed_templates])
              end

            value ->
              {value, acc_processed_templates}
          end

        {upd_in(acc_template, marker, replacement), acc_processed_templates}
    end)
  end
end

defimpl Inspect, for: ProxyConf.MapTemplate do
  import Inspect.Algebra

  def inspect(map_template, opts) do
    concat([
      "#MapTemplate<",
      to_doc(
        [
          template: map_template.template
        ],
        opts
      ),
      ">"
    ])
  end
end
