# HuggingfaceHub

This is a port to Elixir ot Huggingface Hub APIs.

Current functionalities are including:

## Command Line Interface

It is possible to compile the CLI using `mix escript.build` command. At the moment the CLI is just allowing
three user-related commands: login, logout and whoami.

### Logging in
It is needed to put at least the username in command line. The password can be put into after the username or by using the stdin. Once logged in, the token is saved to a local file in order to allow the other commands to use it.

#### Login getting password from command line
```bash
$ ./huggingface_hub --user login stefanof apassword
Login successful
Your token has been saved to /home/stefkohub/.huggingface/token and into git credential store
```

#### Login getting password from stdin
```bash
$ ./huggingface_hub --user login stefanof
password> [characters are hidden while typing]
Login successful
Your token has been saved to /home/stefkohub/.huggingface/token
```

### Logging out
It not needed any parameter. The logout will clean-up the local files used to store the token.
```bash
$ ./huggingface_hub --user logout 
Your token has been deleted from /home/stefkohub/.huggingface/token and from git credential store
```
### Who am I?
It not needed any parameter. The information are taken using the whoami API. At the moment the output is a text containing the Elixir map of whoami response.
```bash
$ ./huggingface_hub --user whoami
%{"avatarUrl" => "/avatars/dceacda2d3d48170cbf5333434182f53.svg", "email" => "stefkohub@example.com", "emailVerified" => true, "fullname" => "StefkoHub", "name" => "stefkohub", "orgs" => [], "periodEnd" => nil, "plan" => "NO_PLAN", "type" => "user"}
```

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

## Repository 

The Repository module allows you to push models or other repositories to the Hub. Repository is a wrapper over Git and Git-LFS methods, so make sure you have Git-LFS installed and set up before you begin. The Repository module should feel familiar if you are already familiar with common Git commands.


### Clone a repository

The `clone_from` parameter clones a repository from a Hugging Face model ID to a directory specified by the `local_dir` argument:

```elixir
iex> alias Huggingface_hub.Repository
iex> {pid, repo} = Repository.repository([local_dir: "./w2v2", clone_from: "facebook/wav2vec2-large-960h-lv60"])
{#PID<0.276.0>, "https://huggingface.co/facebook/wav2vec2-large-960h-lv60"}
```

The repository function is running a GenServer hence the pid is needed to manage the state in next calls. At the moment it is possible to manage one repository at time so a second call do Repository.repository will overwrite previous state. 

`clone_from` can also clone a repository from a specified directory using a URL (if you are working offline, this parameter should not be used):

```elixir
iex> {pid, repo} = Repository.Repository([local_dir: "huggingface-hub", clone_from: "https://github.com/huggingface/huggingface_hub"])
{#PID<0.276.0>, "https://github.com/huggingface/huggingface_hub"}
```

Easily combine the `clone_from` parameter with `create_repo` to create and clone a repository:

```elixir
iex> repo_url = HuggingfaceHub.create_repo("repo_name")
iex> {pid, repo} = Repository([local_dir: "repo_local_path", clone_from: repo_url])
{#PID<0.276.0>, "https://huggingface.co/<path>/<to>/repo_name"}

### Using a local clone

Instantiate a Repository object with a path to a local Git clone or repository:
```elixir
iex> {pid, repo} = Repository.repository(local_dir: "<path>/<to>/<folder>")
```

### Commit and push to a cloned repository

If you want to commit or push to a cloned repository that belongs to you or your organizations:

1. Log in to your Hugging Face account with the following command:

```bash
$ huggingface-cli login
```

1. Instantiate a Repository class:

```elixir
iex> {pid, repo} = Repository.repository([local_dir: "my-model", clone_from: "<user>/<model_id>"])
```

You can also attribute a Git username and email to a cloned repository by specifying the git_user and git_email parameters. When users commit to that repository, Git will be aware of the commit author.

```elixir
iex> {pid, repo} = Repository.repository([
...>   local_dir: "my-dataset", 
...>   clone_from: "<user>/<dataset_id>", 
...>   use_auth_token: true, 
...>   repo_type: "dataset",
...>   git_user: "MyName",
...>   git_email: "me@cool.mail"
...> ])
```

### Branch

Switch between branches with `git_checkout`. For example, if you want to switch from branch1 to branch2:

```elixir
iex> {pid, repo} = Repository.repository([local_dir: "huggingface-hub", clone_from: "<user>/<dataset_id>", revision: 'branch1'])
iex> Repository.git_checkout(pid, "branch2")
```

### Pull

Update a current local branch with `git_pull`:

```elixir
iex> Repository.git_pull(pid)
```

Set rebase to true if you want your local commits to occur after your branch is updated with the new commits from the remote:

```elixir
iex> Repository.git_pull(true)
```

## Commit functionality
The combination between repository and commit functions allow to handle four of the most common Git commands: pull, add, commit, and push. git-lfs automatically tracks any file larger than 10MB. In the following example, the two functionalities:

1. Pull from the text-files repository.
1. Add a change made to file.txt.
1. Commit the change.
1. Push the change to the text-files repository.

```elixir
iex> {pid, repo} = Repository.repository(local_dir="text-files", clone_from="<user>/text-files")
iex> Repository.commit(pid, [commit_message: "My first file :)"], fn ->
...>   File.open("file.txt", [:read, :write], fn file -> 
...>     IO.write(file, "some data here...") 
...>     end)
```

## `push_to_hub`

The Repository module also has a `push_to_hub` utility to add files, make a commit, and push them to a repository. Unlike the commit functionality, `push_to_hub` requires you to pull from a repository first, save the files, and then call `push_to_hub`.

```elixir
iex> Repository.git_pull(pid)
iex> Repository.push_to_hub(pid, commit_message: "Commit my-awesome-file to the Hub")
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
