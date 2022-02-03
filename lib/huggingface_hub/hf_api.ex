defmodule Huggingface_hub.Hf_api do
  # import Logging

  alias Huggingface_hub.Constants
  alias Huggingface_hub.Shared
  alias Huggingface_hub.Hackney, as: Requests

  @username_placeholder "hf_user"
  @remove_filepath_regex ~r/^\w[\w\/\-]*(\.\w+)?$/

  @doc """
    Returns the repo type and ID from a huggingface.co URL linking to a repository
    Args:
        hf_id (``str``):
            An URL or ID of a repository on the HF hub. Accepted values are:
            - https://huggingface.co/<repo_type>/<namespace>/<repo_id>
            - https://huggingface.co/<namespace>/<repo_id>
            - <repo_type>/<namespace>/<repo_id>
            - <namespace>/<repo_id>
            - <repo_id>
  """
  def repo_type_and_id_from_hf_id(hf_id) do

    is_hf_url = (hf_id =~ "huggingface.co" and not (hf_id =~ "@")) 
    url_segments = String.split(hf_id, "/")
    is_hf_id = Enum.count(url_segments) <= 3
    [repo_type, namespace, repo_id] = cond do
      is_hf_url == true ->
        [namespace, repo_id] = Enum.take(url_segments,-2)
        namespace = namespace === "huggingface.co" && nil || namespace
        repo_type = if Enum.count(url_segments) > 2 and not (Enum.at(url_segments, -3) =~ "huggingface.co") do
          Enum.at(url_segments, -3)
        else
          nil
        end
        [repo_type, namespace, repo_id]
      is_hf_id == true ->
          case String.length(url_segments) do
            3    -> Enum.take(url_segments, -3)
            2    -> [Enum.take(String.split(hf_id), -2), nil]
            true -> [Enum.at(url_segments, 0), nil, nil]
          end
      true -> raise ArgumentError, "Unable to retrieve user and repo ID from the passed HF ID: #{hf_id}"
    end

    repo_type =
        repo_type in Constants.repo_types && repo_type || Constants.repo_types_mapping[String.to_atom(repo_type)]

    {repo_type, namespace, repo_id}
  end

  def start_link(endpoint \\ Constants.endpoint) do
    initial_state = %{endpoint: endpoint}
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
    initial_state
  end

  def stop() do
    Agent.stop(__MODULE__)
  end

  def get_state() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def update_state(new) do
    s = get_state()
    new_s = Map.merge(s, new)
    Agent.update(__MODULE__, fn -> new_s end)
  end

  def is_valid_token(state, token) do
    try do
      whoami(state, token)
      true
    catch
      _ -> false
    end
  end

  def whoami(state, token \\ nil) do
    # token = if token === nil, do: HfFolder.get_token(), else: token
    token = if token === nil, do: Enum.at(Shared.read_from_credential_store, 1), else: token
    unless token !== nil do
      raise ArgumentError, "You need to pass a valid `token` or login by using `huggingface-cli login`"
    end
    path = "#{state.endpoint}/api/whoami-v2"
    r = Requests.get(path, [{"authorization", "Bearer #{token}"}],[:with_body])
    d = try do
      Requests.raise_for_status(r)
    catch
      HTTPError -> raise """
        Invalid user token. If you didn't pass a user token, make sure you are properly logged in by
        executing huggingface-cli login, and if you did pass a user token, double-check it's correct.
      """
    end
    Jason.encode!(d)
  end

  def set_access_token(access_token), do: Shared.write_to_credential_store(@username_placeholder, access_token)

  def unset_access_token(), do: Shared.erase_from_credential_store(@username_placeholder)

  def get_model_tags(state) do
    path = "#{state.endpoint}/api/models-tags-by-type"
    r = Requests.get(path, [], [])
    d = Requests.raise_for_status(r)
    {:ok, d} = Jason.decode(d)
    # ModelTags.modelTags(d)
    d
  end

  def get_dataset_tags(state) do
    path = "#{state.endpoint}/api/datasets-tags-by-type"
    r = Requests.get(path, [], [])
    d = Requests.raise_for_status(r)
    {:ok, d} = Jason.decode(d)
    # ModelTags.modelTags(d)
    d
  end

  def list_models(state, filter \\ "", author \\ "", search \\ "", sort \\ "", direction \\ "", limit \\ "", full \\ false, fetch_config \\ "", use_auth_token \\ "") do
    path = "#{state.endpoint}/api/models"
    token = if use_auth_token != "" do
      unless is_valid_token(state, use_auth_token) do
        raise ArgumentError, "Invalid token passed"
      end
    else
      # token = HfFolder.get_token()
      token = Enum.at(Shared.read_from_credential_store, 1)
      unless token != nil do
        raise ArgumentError, "You need to provide a `token` to `use_auth_token` or be logged in to Hugging Face with `huggingface-cli login`."
      end
    end
    headers = (use_auth_token != "" && {"authorization", "Bearer #{token}"}) || []
    # TODO: Check for model filter instance and use unpack_model_filter???
    params = [
      if filter != "" do
        {:filter, filter}
      else
        {}
      end
    ]
    IO.puts "PARAMS=#{inspect params}"
    params = Enum.concat(params, 
        [{:author, author},
        {:search, search},
        {:sort, sort},
        {:direction, direction},
        {:limit, limit}]
    )
    params = ((full == true or filter != "") && Map.merge(params, %{full: true})) || params
    params = (fetch_config != "" && Map.merge(params, %{config: fetch_config})) || params
    IO.puts "#{path} #{inspect headers}, #{inspect params}"
    r = Requests.get(path, headers, params)
    d = Requests.raise_for_status(r)
    Jason.decode!(d)
  end

  def unpack_model_filter(state, model_filter) do
    model_str = Map.has_key?(model_filter, "author") && model_filter.author<>"/" || ""
    model_str = model_str <> (Map.has_key?(model_filter, "model_name") && model_filter.model_name || "")
    filter_tuple = if Map.has_key?(model_filter, "task") do
      [model_filter["task"]]
    else
      []
    end
    filter_tuple = 
      if Map.has_key?(model_filter, "trained_dataset") do
        trained_dataset = if !is_list(model_filter.trained_dataset), do: [model_filter.trained_dataset], else: model_filter.trained_dataset
        Enum.concat(filter_tuple, for dataset <- trained_dataset do
          if not "dataset:" =~ dataset, do: "dataset:#{dataset}", else: dataset
        end)
      else
        filter_tuple
    end
    filter_tuple = 
      if Map.has_key?(model_filter, "library") do
        library = if !is_list(model_filter.library), do: [model_filter.library], else: model_filter.library
        Enum.concat(filter_tuple, library)
      else
        filter_tuple
      end
    tags = 
      if Map.has_key?(model_filter, "tags") do
        if is_binary(model_filter["tags"]), do: [model_filter["tags"]], else: model_filter["tags"]
      else
        []
    end

    query_dict = %{
      search: model_str,
      tags: tags,
      filter: Map.has_key?(model_filter, "language") && Enum.concat(filter_tuple, model_filter["language"]) || filter_tuple 
    }
    IO.puts "Qui query_dict=#{inspect query_dict}"
    query_dict
  end

  def list_datasets(state, filter \\ "", author \\ "", search \\ "", sort \\ "", direction \\ "", limit \\ "", full \\ false, use_auth_token \\ "") do
    path = "#{state.endpoint}/api/datasets"
    token = if use_auth_token != "" do
      unless is_valid_token(state, use_auth_token) do
        raise ArgumentError, "Invalid token passed"
      end
    else
      # token = HfFolder.get_token()
      token = Enum.at(Shared.read_from_credential_store, 1)
      unless token != nil do
        raise ArgumentError, "You need to provide a `token` to `use_auth_token` or be logged in to Hugging Face with `huggingface-cli login`."
      end
    end
    headers = (use_auth_token != "" && {"authorization", "Bearer #{token}"}) || []
    # TODO: Check for model filter instance and use unpack_dataset_filter???
    params = [
      if filter != "" do
        {:filter, filter}
      else
        {}
      end
    ]
    params = Enum.concat(params, 
        [{:author, author},
        {:search, search},
        {:sort, sort},
        {:direction, direction},
        {:limit, limit}]
    )
    params = ((full == true or filter != "") && Map.merge(params, %{full: true})) || params
    r = Requests.get(path, headers, params)
    d = Requests.raise_for_status(r)
    Jason.decode!(d)
  end

  @doc """
    Get the public list of all the metrics on huggingface.co
  """
  def list_metrics(state) do
    path = "#{state.endpoint}/api/metrics"
    r = Requests.get(path, [], [])
    d = Requests.raise_for_status(r)
    Jason.decode!(d)
  end

  @doc """
    Get info on one specific model on huggingface.co
    Model can be private if you pass an acceptable token or are logged in.
  """
  def model_info(state, repo_id, revision \\ "", token \\ "", timeout \\ "") do
    token = (token == "" && Enum.at(Shared.read_from_credential_store, 1)) || token
    path = (revision == "" && "#{state.endpoint}/api/models/#{repo_id}") || "#{state.endpoint}/api/models/#{repo_id}/revision/#{revision}"
    headers = (token != "" && [{"authorization", "Bearer #{token}"}]) || []
    r = Requests.get(path, headers, [])
    d = Requests.raise_for_status(r)
    Jason.decode!(d)
  end

  @doc """
    Get the list of files in a given repo.
  """
  def list_repo_files(state, repo_id, revision \\ "", repo_type \\ "", token \\ "", timeout \\ "") do
    info = 
      cond do
        repo_type == "" or repo_type == "model" ->
          model_info(state, repo_id, revision, token, timeout)
        repo_type == "dataset" ->
          dataset_info(state, repo_id, revision, token, timeout)
        true ->
          raise ArgumentError, "Spaces are not available yet."
      end
    for f <- info.sibilings, do: f.rfilename
  end

  @doc """
    Get info on one specific dataset on huggingface.co
    Dataset can be private if you pass an acceptable token.
  """
  def dataset_info(state, repo_id, revision \\ "", token \\ "", timeout \\ "") do
    path = (revision == "" && "#{state.endpoint}/api/datasets/#{repo_id}") || "#{state.endpoint}/api/datasets/#{repo_id}/revision/#{revision}"
    headers = (token != "" && [{"authorization", "Bearer #{token}"}]) || []
    params = [{:full, "true"}]
    r = Requests.get(path, headers, params)
    d = Requests.raise_for_status(r)
    Jason.decode!(d)
  end


end
