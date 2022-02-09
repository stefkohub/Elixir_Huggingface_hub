defmodule Huggingface_hub.ModelTags do
  use Huggingface_hub.GeneralTags

  def get_tags(tag_dictionary) do
    {pid, state} = start_link(tag_dictionary)
    IO.puts("Adesso state=#{inspect(state)}")
    state
  end
end
