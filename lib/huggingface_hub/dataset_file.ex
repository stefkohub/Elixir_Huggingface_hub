defmodule Huggingface_hub.DatasetFile do
  @moduledoc """
    Data structure that represents a public file inside a model, accessible from huggingface.co
  """
  def start_link(opts) do
    initial_state = opts
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
    initial_state
  end

  def get_state(_node_name) do
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
