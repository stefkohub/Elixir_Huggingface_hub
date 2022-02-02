defmodule Huggingface_hub.RepoObj do
  @moduledoc """
    HuggingFace git-based system, data structure that represents a file belonging to the current user.
  """
  def start_link(opts) do
    initial_state = opts
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
    initial_state
  end

  def get_state(node_name) do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def repr(state) do
    items = Enum.join(
      for {k,v} <- state do
        "#{k}=#{v}"
      end,
    ", ")
    "#{__MODULE__}(#{items})"
  end
end
