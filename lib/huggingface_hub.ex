defmodule HuggingfaceHub do
  @moduledoc """
  Documentation for `HuggingfaceHub`.
  """

  alias Huggingface_hub.Hf_api
  alias Huggingface_hub.Constants
  alias Huggingface_hub.Shared
  alias Huggingface_hub.HfFolder

  require Logger

  @doc """

  """
  @public_hf_apis [
    login: [2..2],
    logout: [1..1],
    whoami: [0..1],
    get_model_tags: [0..0],
    get_dataset_tags: [0..0],
    list_models: [0..1],
    list_datasets: [0..1],
    model_info: [1..4],
    dataset_info: [1..4],
    list_metrics: [0..0],
    get_full_repo_name: [1..3],
    list_repo_files: [1..5],
    create_repo: [1..8],
    delete_repo: [1..4],
    update_repo_visibility: [2..5]
  ]

  for {api, [arities]} <- @public_hf_apis do
    for arity <- arities do
      args = Macro.generate_arguments(arity, __MODULE__)
      def unquote(api)(unquote_splicing(args)) do
        apply(Hf_api, unquote(api), unquote(args))
      end
    end
  end

end
