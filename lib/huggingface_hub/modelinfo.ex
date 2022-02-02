defmodule Huggingface_hub.ModelInfo do

  def start_link(opts) do
    {modelId, opts} =  Keywords.pop(opts, :modelId, nil)
    {sha, opts} =  Keywords.pop(opts, :sha, nil)
    {lastModified, opts} =  Keywords.pop(opts, :lastModified, nil)
    {tags, opts} =  Keywords.pop(opts, :tags, [])
    {pipeline_tag, opts} =  Keywords.pop(opts, :pipeline_tag, nil)
    {sibilings, opts} =  ModelFile.start_link(Keywords.pop(opts, :sibilings, []))
    {config, opts} =  Keywords.pop(opts, :config, [])
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
