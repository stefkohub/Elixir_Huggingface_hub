defmodule Huggingface_hub.DatasetInfo do

  alias Huggingface_hub.DatasetFile

  def start_link(opts) do
    {id, opts} =  Keyword.pop(opts, :id, nil)
    {lastModified, opts} =  Keyword.pop(opts, :lastModified, nil)
    {tags, opts} =  Keyword.pop(opts, :tags, [])
    {sibilings, opts} =  DatasetFile.start_link(Keyword.pop(opts, :sibilings, []))
    {private, opts} =  Keyword.pop(opts, :private, false)
    {author, opts} =  Keyword.pop(opts, :author, false)
    {description, opts} =  Keyword.pop(opts, :description, false)
    {citation, opts} =  Keyword.pop(opts, :citation, false)
    {cardData, opts} =  Keyword.pop(opts, :cardData, false)
    {_, opts} = Keyword.pop(opts,:key, "")
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

