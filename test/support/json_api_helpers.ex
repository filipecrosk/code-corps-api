defmodule CodeCorps.JsonAPIHelpers do
  @moduledoc ~S"""
  Contains helpers used to build a Json API structured payload from a flat
  attributes map.
  """

  @spec build_json_payload(map) :: map
  def build_json_payload(attrs = %{}) do
    %{
      "data" => %{
        "attributes" => attrs |> build_attributes(),
        "relationships" => attrs |> build_relationships()
      }
    }
  end

  @spec build_attributes(map) :: map
  defp build_attributes(%{} = attrs) do
    attrs
    |> Enum.filter(&attribute?(&1))
    |> Enum.reduce(%{}, &add_attribute(&1, &2))
  end

  @spec attribute?(tuple) :: boolean
  defp attribute?({_key, %DateTime{} = _val}), do: true
  defp attribute?({_key, val}) when is_map(val), do: false
  defp attribute?({_key, _val}), do: true

  @spec add_attribute(tuple, map) :: map
  defp add_attribute({key, value}, %{} = attrs) do
    attrs |> Map.put(key |> Atom.to_string, value)
  end

  @spec build_relationships(map) :: map
  defp build_relationships(%{} = attrs) do
    attrs
    |> Enum.filter(&relationship?(&1))
    |> Enum.reduce(%{}, &add_relationship(&1, &2))
  end

  @spec relationship?(any) :: boolean
  defp relationship?(tupple), do: !attribute?(tupple)

  @spec add_attribute(tuple, map) :: map
  defp add_relationship({atom_key, record}, %{} = rels) do
    with id <- record.id |> to_correct_type(),
         type <- record |> model_name_as_string(),
         string_key = atom_key |> Atom.to_string
    do
      rels |> Map.put(string_key, %{"data" => %{"id" => id, "type" => type}})
    end
  end

  @spec model_name_as_string(struct) :: String.t
  defp model_name_as_string(record) do
    record.__struct__
    |> Module.split
    |> List.last
    |> String.downcase
  end

  @spec to_correct_type(any) :: any
  defp to_correct_type(value) when is_integer(value), do: value |> Integer.to_string
  defp to_correct_type(value), do: value
end
