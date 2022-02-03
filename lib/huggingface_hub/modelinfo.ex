defmodule Huggingface_hub.ModelInfo do

  def start_link(opts) do
    {modelId, opts} =  Keyword.pop(opts, :modelId, nil)
    {sha, opts} =  Keyword.pop(opts, :sha, nil)
    {lastModified, opts} =  Keyword.pop(opts, :lastModified, nil)
    {tags, opts} =  Keyword.pop(opts, :tags, [])
    {pipeline_tag, opts} =  Keyword.pop(opts, :pipeline_tag, nil)
    {sibilings, opts} =  ModelFile.start_link(Keyword.pop(opts, :sibilings, []))
    {config, opts} =  Keyword.pop(opts, :config, [])
    initial_state = Map.merge(%{
      :modelId => modelId,
      :sha => sha,
      :lastModified => lastModified,
      :tags => tags,
      :pipeline_tag => pipeline_tag,
      :sibilings => sibilings,
      :config => config,
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
    r = "Model Name: #{state.modelId}, Tags: #{inspect(state.tags)}"
    add_r = state.pipeline_tag == true && ", Task: #{self.pipeline_tag}" || ""
    r <> add_r
  end
end
