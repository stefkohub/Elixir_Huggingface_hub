defmodule Huggingface_hub.DatasetInfo do

  alias Huggingface_hub.DatasetFile

  def start_link(opts) do
    {id, opts} =  Keywords.pop(opts, :id, nil)
    {lastModified, opts} =  Keywords.pop(opts, :lastModified, nil)
    {tags, opts} =  Keywords.pop(opts, :tags, [])
    {sibilings, opts} =  DatasetFile.start_link(Keywords.pop(opts, :sibilings, []))
    {private, opts} =  Keywords.pop(opts, :private, false)
    {author, opts} =  Keywords.pop(opts, :author, false)
    {description, opts} =  Keywords.pop(opts, :description, false)
    {citation, opts} =  Keywords.pop(opts, :citation, false)
    {cardData, opts} =  Keywords.pop(opts, :cardData, false)
    {_, opts} = Keywords.pop(opts,:key, "")
    initial_state = Map.merge(%{
      id => id,
      lastModified => lastModified,
      tags => tags,
      sibilings => sibilings,
      private => private,
      author => author,
      description => description,
      citation => citation,
      cardData => cardData,
    }, opts)
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
    initial_state
  end

  def repr(state) do
    "#{__MODULE__}: {" <>
      Enum.join(for {key, val} <- state do
        "\t#{key}: #{val}"
      end, "\n")
    <>"\n}"
  end

  def str(state) do
    "Dataset Name: #{state.id}, Tags: #{inspect(state.tags)}"
  end
end

