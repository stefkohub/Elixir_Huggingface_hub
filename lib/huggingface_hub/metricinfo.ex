defmodule Huggingface_hub.MetricInfo do

  def start_link(opts) do
    {id, opts} =  Keyword.pop(opts, :id, nil)
    {description, opts} =  Keyword.pop(opts, :description, false)
    {citation, opts} =  Keyword.pop(opts, :citation, false)
    {_, opts} = Keyword.pop(opts,:key, "")
    initial_state = Map.merge(%{
      id => id,
      description => description,
      citation => citation,
      }, opts)
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
    initial_state
  end

  def repr(state) do
    s = "#{__MODULE__}: {" <>
      Enum.join(for {key, val} <- state do
        "\t#{key}: #{val}"
      end, "\n")
    <>"\n}"
  end

  def str(state) do
    "Metric Name: #{state.id}"
  end
end

