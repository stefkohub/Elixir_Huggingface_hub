defmodule Huggingface_hub.Constants do
  @staging_mode false

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

  def repo_types, do: ["", @repo_type_model, @repo_type_dataset, @repo_type_space]
  def spaces_sdk_types, do: ["gradio", "streamlit", "static"]

  def repo_types_url_prefixes,
    do: %{
      unquote(@repo_type_dataset) => "datasets/",
      unquote(@repo_type_space) => "spaces/"
    }

  def repo_types_mapping,
    do: %{
      datasets: @repo_type_dataset,
      spaces: @repo_type_space,
      models: @repo_type_model
    }

  def lfs_multipart_upload_command, do: "lfs-multipart-upload"
end
