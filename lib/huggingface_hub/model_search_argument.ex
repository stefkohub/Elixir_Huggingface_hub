defmodule Huggingface_hub.ModelSearchArguments do
  alias Huggingface_hub.HfApi

  @moduledoc """
    A nested namespace object holding all possible values for properties of
    models currently hosted in the Hub with tab-completion.
    If a value starts with a number, it will only exist in the dictionary
    Example:
        >>> args = ModelSearchArguments()
        >>> args.author_or_organization.huggingface
        >>> args.language.en
  """

  def start_link(args) do
    api = HfApi.start_link()
    tags = HfApi.get_model_tags(api)

    initial_state = %{
      :api => api,
      :tag => tags
    }

    Agent.start_link(fn -> initial_state end, name: __MODULE__)
    process_models(initial_state)
  end

  defp clean(s) do
    String.replace(s, " ", "") |> String.replace("-", "_") |> String.replace(".", "_")
  end

  def process_models(state) do
    models = HfApi.list_models(state.api)
    #  [author_dict, model_name_dict] = [[], []]
    {author_dict, model_name_dict} =
      for model <- models do
        if "/" =~ model.modelId do
          [author, name] = String.split(model.modelId, "/")
          [{author, clean(author)}, {name, clean(name)}]
        else
          [{}, {model.modelId, clean(model.modelId)}]
        end
      end

    state =
      Map.merge(state, %{
        model_name: model_name_dict,
        author: author_dict
      })
  end
end
