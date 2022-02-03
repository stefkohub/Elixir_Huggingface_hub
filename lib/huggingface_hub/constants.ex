defmodule Huggingface_hub.Constants do

  @staging_mode true

  def endpoint when @staging_mode == true, do: "https://moon-staging.huggingface.co"
  def endpoint when @staging_mode != true, do:  "https://huggingface.co"

  @repo_type_dataset "dataset"
  @repo_type_space "space"
  @repo_type_model "model"
  @repo_types [nil, @repo_type_model, @repo_type_dataset, @repo_type_space]
  @spaces_sdk_types ["gradio", "streamlit", "static"]

  @repo_types_mapping  %{
    datasets: @repo_type_dataset,
    spaces: @repo_type_space,
    models: @repo_type_model
  }

  def repo_types, do: @repo_types
  def repo_types_mapping, do: @repo_types_mapping

end

