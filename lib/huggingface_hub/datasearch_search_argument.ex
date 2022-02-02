defmodule Huggingface_hub.DatasetSearchArguments do

  alias Huggingface_hub.HfApi

  @moduledoc  """
    A nested namespace object holding all possible values for properties of
    datasets currently hosted in the Hub with tab-completion.
    If a value starts with a number, it will only exist in the dictionary
    Example:
        >>> args = DatasetSearchArguments()
        >>> args.author_or_organization.huggingface
        >>> args.language.en
  """

  def start_link(args) do
    api = HfApi.start_link()
    tags = HfApi.get_dataset_tags(api)
    initial_state = %{
      :api => api,
      :tag => tags
    }
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
    process_datasets(initial_state)
  end

  defp clean(s) do
    String.replace(s," ", "") |> String.replace("-", "_") |> String.replace(".", "_")
  end

  def process_datasets(state) do
     datasets = HfApi.list_datasets(state.api)
     {author_dict, dataset_name_dict} = for dataset <- datasets do
       if "/" =~ dataset.datasetId do
         [author, name] = String.split(dataset.datasetId, "/")
         [{author, clean(author)}, {name, clean(name)}]
       else
         [{}, {dataset.datasetId, clean(dataset.datasetId)}]
       end
     end
     state = Map.merge(state, %{
       dataset_name: dataset_name_dict,
       author: author_dict
     })
   end

end
