defmodule Huggingface_hub.Constants do

  @staging_mode true

  def hf_endpoint do
    if @staging_mode === true do
      "https://moon-staging.huggingface.co"
    else
      "https://huggingface.co"
    end
  end

  @repo_type_dataset "dataset"
  @repo_type_space "space"
  @repo_type_model "model"
  def repo_types, do:  [nil, @repo_type_model, @repo_type_dataset, @repo_type_space]
  def spaces_sdk_types, do:  ["gradio", "streamlit", "static"]

  def repo_types_mapping, do: %{
        datasets: @repo_type_dataset,
        spaces: @repo_type_space,
        models: @repo_type_model
      }

   #def repo_types, do: @repo_types
   #def repo_types_mapping, do: @repo_types_mapping
end
