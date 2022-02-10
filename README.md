# HuggingfaceHub

This is a port to Elixir ot Huggingface Hub APIs.

Current functionalities are including:

## Model listing

```elixir
# List all models.
iex> HuggingfaceHub.list_models()

# List only text classification models.
iex> HuggingfaceHub.list_models(filter: "text-classification")

# List only Russian models compatible with PyTorch.
iex> HuggingfaceHub.list_models(filter: ["languages:ru", "pytorch"])

# List only the models trained on the "common_voice" dataset.
iex> HuggingfaceHub.list_models(filter: "dataset:common_voice")

# List only the models from the spaCy library.
iex> HuggingfaceHub.list_models(filter: "spacy")
```

## Explore available public datasets with `list_datasets`:

```elixir
# List only text classification datasets.
iex> HuggingfaceHub.list_datasets(filter: "task_categories:text-classification")

# List only datasets in Russian for language modeling.
iex> HuggingfaceHub.list_datasets(filter: ["languages:ru", "task_ids:language-modeling"])

```

## Inspect model or dataset metadata

Get important information about a model or dataset as shown below:

```elixir
# Get metadata of a single model.
iex> HuggingfaceHub.model_info("distilbert-base-uncased")

# Get metadata of a single dataset.
iex> HuggingfaceHub.dataset_info("glue")
```

## Create a repository

Create a repository with `create_repo` and give it a name with the name parameter.

```elixir
iex> HuggingfaceHub.create_repo("test-model")
'https://huggingface.co/stefkohub/test-model'
```

## Delete a repository

Delete a repository with `delete_repo`. Make sure you are certain you want to delete a repository because this is an irreversible process!

Pass the full repository ID to `delete_repo`. The full repository ID looks like `{username_or_org}/{repo_name}`, and you can retrieve it with `get_full_repo_name()` as shown below:

```elixir
iex> name = HuggingfaceHub.get_full_repo_name(repo_name)
iex> HuggingfaceHub.delete_repo(name=name)
```

## Delete a dataset repository by adding the `repo_type` parameter:

```elixir
iex> HuggingfaceHub.delete_repo(REPO_NAME, "dataset")
```

## Change repository visibility

A repository can be public or private. A private repository is only visible to you or members of the organization in which the repository is located. Change a repository to private as shown in the following:

```elixir
iex> HuggingfaceHub.update_repo_visibility(REPO_NAME, true)
```

## Upload a file to a repository

The `upload_file` method uploads files to the Hub. This method requires the following:

- A path to the file to upload.
- The final path in the repository.
- The repository you wish to push the files to.

For example:
```elixir
iex> HuggingfaceHub.upload_file("/home/dummy-test/README.md", "README.md", "stefkohub/test-model")
'https://huggingface.co/stefkohub/test-model/blob/main/README.md'
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `huggingface_hub` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:huggingface_hub, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/huggingface_hub](https://hexdocs.pm/huggingface_hub).

