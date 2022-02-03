defmodule Huggingface_hub.GeneralTags do

  defmacro __using__(_opts) do
    quote do
      def start_link(tag_dictionary, keys \\ []) do
        initial_state = %{
          tag_dictionary: tag_dictionary,
          keys: keys != [] && keys || Map.keys(tag_dictionary)
        }
        add_to_state = for key <- keys, into: %{}, do: unpack_and_assign_dictionary(initial_state,key)
        IO.puts "Add to state=#{inspect add_to_state}"
        {:ok, pid} = Agent.start_link(fn -> Map.merge(initial_state, add_to_state) end)
        {pid, initial_state}
      end

      def stop(pid) do
        Agent.stop(pid)
      end

      def get_state(pid) do
        Agent.get(pid, fn state -> state end)
      end

      def unpack_and_assign_dictionary(state, key) do
        key_items = for item <- state.tag_dictionary[key] do
          ref = Map.get(state, key, %{label: "", id: ""})
          %{
            label: String.replace(item.label, " ", "")|>String.replace("-", "_")|>String.replace(".", "_"),
            item: item.id
          }
        end
        new_state = Map.merge(state, {key, key_items})
      end

      defoverridable unpack_and_assign_dictionary: 2
    end
  end

end
