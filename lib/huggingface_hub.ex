defmodule HuggingfaceHub do
  @moduledoc """
  Documentation for `HuggingfaceHub`.
  """

  alias Huggingface_hub.Hf_api
  alias Huggingface_hub.Constants
  alias Huggingface_hub.Shared
  alias Huggingface_hub.HfFolder

  require Logger

  # @doc """

  # """
  @public_hf_apis [
    login: [2..2, Hf_api],
    logout: [1..1, Hf_api],
    whoami: [0..1, Hf_api],
    get_model_tags: [0..0, Hf_api],
    get_dataset_tags: [0..0, Hf_api],
    list_models: [0..1, Hf_api],
    list_datasets: [0..1, Hf_api],
    model_info: [1..4, Hf_api],
    dataset_info: [1..4, Hf_api],
    list_metrics: [0..0, Hf_api],
    get_full_repo_name: [1..3, Hf_api],
    list_repo_files: [1..5, Hf_api],
    create_repo: [1..8, Hf_api],
    delete_repo: [1..4, Hf_api],
    update_repo_visibility: [2..5, Hf_api]
  ]

  for {api, [arities, module]} <- @public_hf_apis do
    for arity <- arities do
      args = Macro.generate_arguments(arity, __MODULE__)

      @doc """
        For more information please see #{module}.#{api}/#{arity}
      """
      def unquote(api)(unquote_splicing(args)) do
        apply(unquote(module), unquote(api), unquote(args))
      end
    end
  end
end
