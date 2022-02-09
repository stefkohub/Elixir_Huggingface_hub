defmodule Huggingface_hub.Hf_api do
  # import Logging

  alias Huggingface_hub.Constants
  alias Huggingface_hub.Shared
  alias Huggingface_hub.HfFolder
  alias Huggingface_hub.Hackney, as: Requests
  require Logger

  @username_placeholder "hf_user"
  @remote_filepath_regex ~r/^\w[\w\/\-]*(\.\w+)?$/
  # ^^ No trailing slash, no backslash, no spaces, no relative parts ("." or "..")
  #    Only word characters and an optional extension

  @remove_filepath_regex ~r/^\w[\w\/\-]*(\.\w+)?$/
  @initial_state %{endpoint: Constants.hf_endpoint()}

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
  defp repo_type_and_id_from_hf_id(hf_id) do
    is_hf_url = hf_id =~ "huggingface.co" and not (hf_id =~ "@")
    url_segments = String.split(hf_id, "/")
    is_hf_id = Enum.count(url_segments) <= 3

    [repo_type, namespace, repo_id] =
      cond do
        is_hf_url == true ->
          [namespace, repo_id] = Enum.take(url_segments, -2)
          namespace = (namespace === "huggingface.co" && nil) || namespace

          repo_type =
            if Enum.count(url_segments) > 2 and
                 not (Enum.at(url_segments, -3) =~ "huggingface.co") do
              Enum.at(url_segments, -3)
            else
              nil
            end

          [repo_type, namespace, repo_id]

        is_hf_id == true ->
          case Enum.count(url_segments) do
            3 -> Enum.take(url_segments, -3)
            2 -> [""] ++ Enum.take(url_segments, -2)
            _ -> ["", ""] ++ Enum.at(url_segments, 0)
          end

        true ->
          raise ArgumentError,
                "Unable to retrieve user and repo ID from the passed HF ID: #{hf_id}"
      end

    repo_type =
      (repo_type in Constants.repo_types() && repo_type) ||
        Constants.repo_types_mapping()[String.to_atom(repo_type)]

    {repo_type, namespace, repo_id}
  end

  @doc """
        Call HF API to sign in a user and get a token if credentials are valid.
        Outputs: token if credentials are valid
        Throws: requests.exceptions.HTTPError if credentials are invalid
  """
  def login(username, password) do
    # That's not true.
    # Logger.error("HfApi.login: This method is deprecated in favor of `set_access_token`.")
    state = @initial_state

    path = "#{state.endpoint}/api/login"
    params = Jason.encode!(%{username: username, password: password})
    r = Requests.post(path, [{"content-type", "application/json"}], [:with_body], params)
    d = Jason.decode!(Requests.raise_for_status(r))
    Shared.write_to_credential_store(username, password)
    d["token"]
  end

  def logout(token) do
    # That's not true.
    # Logger.error("HfApi.login: This method is deprecated in favor of `unset_access_token`.")
    state = @initial_state
    username = whoami(token)["name"]
    Shared.erase_from_credential_store(username)
    path = "#{state.endpoint}/api/logout"
    r = Requests.auth_post(path, token, [], [:with_body], [])
    Jason.decode!(Requests.raise_for_status(r))
  end

  defp is_valid_token?(token) do
    try do
      whoami(token)
      true
    catch
      _ -> false
    end
  end

  def whoami(token \\ "") do
    state = @initial_state
    {:ok, token} = if token === "", do: HfFolder.get_token(), else: {:ok, token}

    unless token !== "" do
      raise ArgumentError,
            "You need to pass a valid `token` or login by using `huggingface-cli login`"
    end

    path = "#{state.endpoint}/api/whoami-v2"
    r = Requests.auth_get(path, token, [])

    d =
      try do
        Requests.raise_for_status(r)
      rescue
        err in HTTPError ->
          raise """
            Invalid user token. If you didn't pass a user token, make sure you are properly logged in by
            executing huggingface-cli login, and if you did pass a user token, double-check it's correct.
            Error trace: #{inspect(err)}
          """
      end

    Jason.decode!(d)
  end

  def set_access_token(access_token),
    do: Shared.write_to_credential_store(@username_placeholder, access_token)

  def unset_access_token(), do: Shared.erase_from_credential_store(@username_placeholder)

  @get_tags ["model", "dataset"]

  for what <- @get_tags do
    def unquote(String.to_atom("get_#{what}_tags"))() do
      state = @initial_state
      path = "#{state.endpoint}/api/#{unquote(what)}s-tags-by-type"
      r = Requests.get(path)
      d = Requests.raise_for_status(r)
      {:ok, d} = Jason.decode(d)
      d
    end

    # TODO: In datasets there is no fetch_config
    def unquote(String.to_atom("list_#{what}s"))(kwargs \\ []) do
      state = @initial_state

      kw = %{
        filter: Keyword.get(kwargs, :filter, ""),
        author: Keyword.get(kwargs, :author, ""),
        search: Keyword.get(kwargs, :search, ""),
        sort: Keyword.get(kwargs, :sort, ""),
        direction: Keyword.get(kwargs, :direction, ""),
        limit: Keyword.get(kwargs, :limit, ""),
        full: Keyword.get(kwargs, :full, false),
        fetch_config: Keyword.get(kwargs, :fetch_config, ""),
        use_auth_token: Keyword.get(kwargs, :use_auth_token, "")
      }

      path = "#{state.endpoint}/api/#{unquote(what)}s"

      token =
        if kw.use_auth_token != "" do
          unless is_valid_token?(kw.use_auth_token) do
            raise ArgumentError, "Invalid token passed"
          end
        else
          {:ok, token} = HfFolder.get_token()

          unless token != nil do
            raise ArgumentError,
                  "You need to provide a `token` to `use_auth_token` or be logged in to Hugging Face with `huggingface-cli login`."
          end
        end

      # TODO: Check for model filter instance and use unpack_model_filter???
      querystring =
        if kw.filter != "" do
          [filter: kw.filter]
        else
          []
        end

      querystring =
        Enum.concat(
          querystring,
          for q <- [:author, :search, :sort, :direction, :limit, :fetch_config], kw[q] != "" do
            kw[q] != "" && {q, kw[q]}
          end
        )

      IO.puts("PARAMS=#{inspect(querystring)}")

      querystring =
        ((kw.full == true or kw.filter != "") && Enum.concat(querystring, full: true)) ||
          querystring

      # querystring =
      #  (kw.fetch_config != "" && Enum.concat(querystring, config: kw.fetch_config)) || querystring

      if kw.use_auth_token != "" do
        Requests.auth_get(path, token, [], querystring)
      else
        Requests.get(path, [], querystring)
      end
      |> Requests.raise_for_status()
      |> Jason.decode!()
    end

    @doc """
      Get info on one specific #{what} on huggingface.co
      Model can be private if you pass an acceptable token or are logged in.
    """
    def unquote(String.to_atom("#{what}_info"))(
          repo_id,
          revision \\ "",
          token \\ "",
          timeout \\ ""
        ) do
      state = @initial_state
      {:ok, token} = if token === nil, do: HfFolder.get_token(), else: {:ok, token}

      path =
        (revision == "" && "#{state.endpoint}/api/#{unquote(what)}s/#{repo_id}") ||
          "#{state.endpoint}/api/#{unquote(what)}s/#{repo_id}/revision/#{revision}"

      params =
        if unquote(what) == "dataset" do
          [{:full, "true"}]
        else
          []
        end

      r =
        if token != "" do
          Requests.auth_get(path, token, [], params)
        else
          Requests.get(path, [], params)
        end

      d = Requests.raise_for_status(r)
      Jason.decode!(d)
    end
  end

  # TODO: See if use it
  def unpack_model_filter(model_filter) do
    model_str = (Map.has_key?(model_filter, "author") && model_filter.author <> "/") || ""

    model_str =
      model_str <> ((Map.has_key?(model_filter, "model_name") && model_filter.model_name) || "")

    filter_tuple =
      if Map.has_key?(model_filter, "task") do
        [model_filter["task"]]
      else
        []
      end

    filter_tuple =
      if Map.has_key?(model_filter, "trained_dataset") do
        trained_dataset =
          if !is_list(model_filter.trained_dataset),
            do: [model_filter.trained_dataset],
            else: model_filter.trained_dataset

        Enum.concat(
          filter_tuple,
          for dataset <- trained_dataset do
            if not "dataset:" =~ dataset, do: "dataset:#{dataset}", else: dataset
          end
        )
      else
        filter_tuple
      end

    filter_tuple =
      if Map.has_key?(model_filter, "library") do
        library =
          if !is_list(model_filter.library),
            do: [model_filter.library],
            else: model_filter.library

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
      filter:
        (Map.has_key?(model_filter, "language") &&
           Enum.concat(filter_tuple, model_filter["language"])) || filter_tuple
    }

    IO.puts("Qui query_dict=#{inspect(query_dict)}")
    query_dict
  end

  @doc """
    Get the public list of all the metrics on huggingface.co
  """
  def list_metrics() do
    state = @initial_state
    path = "#{state.endpoint}/api/metrics"
    r = Requests.get(path)
    d = Requests.raise_for_status(r)
    Jason.decode!(d)
  end

  @doc """
    Returns the repository name for a given model ID and optional organization.
    Args:
        model_id (``str``):
            The name of the model.
        organization (``str``, `optional`):
            If passed, the repository name will be in the organization namespace instead of the
            user namespace.
        token (``str``, `optional`):
            The Hugging Face authentication token
    Returns:
        ``str``: The repository name in the user's namespace ({username}/{model_id}) if no
        organization is passed, and under the organization namespace ({organization}/{model_id})
        otherwise.
  """
  def get_full_repo_name(model_id, organization \\ "", token \\ "") do
    if organization == "" do
      username =
        if model_id =~ "/" do
          Enum.at(String.split(model_id, "/"), 0)
        else
          whoami(token)["name"]
        end

      "#{username}/#{model_id}"
    else
      "#{organization}/#{model_id}"
    end
  end

  @doc """
    Get the list of files in a given repo.
  """
  def list_repo_files(
        repo_id,
        revision \\ "",
        repo_type \\ "",
        token \\ "",
        timeout \\ ""
      ) do
    state = @initial_state

    info =
      cond do
        repo_type == "" or repo_type == "model" ->
          model_info(repo_id, revision, token, timeout)

        repo_type == "dataset" ->
          dataset_info(repo_id, revision, token, timeout)

        true ->
          raise ArgumentError, "Spaces are not available yet."
      end

    for f <- info["siblings"], do: f["rfilename"]
  end

  def create_repo(
        name,
        token \\ nil,
        organization \\ "",
        private \\ "",
        repo_type \\ "",
        exist_ok \\ false,
        lfsmultipartthresh \\ "",
        space_sdk \\ ""
      ) do
    state = @initial_state
    path = "#{state.endpoint}/api/repos/create"
    {:ok, token} = if token === nil, do: HfFolder.get_token(), else: {:ok, token}

    unless token !== "" do
      raise ArgumentError,
            "You need to provide a `token` or be logged in to Hugging Face with `huggingface-cli login`."
    else
      if !is_valid_token?(token) do
        raise ArgumentError, "Invalid token passed!"
      end
    end

    checked_name = repo_type_and_id_from_hf_id(name)

    if repo_type !== "" and elem(checked_name, 0) != "" and repo_type != elem(checked_name, 0),
      do:
        raise(
          ArgumentError,
          "Passed `repo_type` and found `repo_type` are not the same (#{repo_type}, #{elem(checked_name, 0)}).  Please make sure you are expecting the right type of repository to exist."
        )

    if organization !== "" and elem(checked_name, 1) != "" and repo_type != elem(checked_name, 1),
      do:
        raise(
          ArgumentError,
          "Passed `organization` and `name` organization are not the same (#{organization}, #{elem(checked_name, 1)}). Please either include the organization in only `name` or the `organization` parameter, such as `api.create_repo(#{elem(checked_name, 0)}, organization=#{organization})` or `api.create_repo(#{elem(checked_name, 1)}/#{elem(checked_name, 2)})`"
        )

    repo_type = (elem(checked_name, 0) != "" && elem(checked_name, 0)) || repo_type
    organization = (elem(checked_name, 1) != "" && elem(checked_name, 1)) || organization
    name = elem(checked_name, 2)

    if repo_type not in Constants.repo_types(),
      do: raise(ArgumentError, "Invalid repo type: #{inspect(repo_type)}")

    json = %{name: name, organization: organization, private: private}
    json = (repo_type != "" && Map.merge(json, %{type: repo_type})) || json

    json =
      if repo_type == "space" do
        if space_sdk != "",
          do:
            raise(
              ArgumentError,
              "No space_sdk provided. `create_repo` expects space_sdk to be one of {@spaces_sdk_types} when repo_type is 'space'`"
            )

        if space_sdk not in Constants.spaces_sdk_types(),
          do:
            raise(
              ArgumentError,
              "Invalid space_sdk. Please choose one of #{Constants.spaces_sdk_types()}."
            )

        Map.merge(json, %{sdk: space_sdk})
      else
        json
      end

    if space_sdk != "" and repo_type != "space",
      do: Logger.warning("Ignoring provided space_sdk because repo_type is not 'space'.")

    json =
      if lfsmultipartthresh != "" do
        Map.merge(json, %{lfsmultipartthresh: lfsmultipartthresh})
      else
        json
      end

    r =
      Requests.auth_post(
        path,
        token,
        [{"content-type", "application/json"}],
        [:with_body],
        Jason.encode!(json)
      )

    d =
      try do
        Requests.raise_for_status(r)
      rescue
        err ->
          if not (exist_ok != "" and err.status_code == 409) do
            try do
              additional_info = Jason.decode!(r)["error"]

              new_err =
                (additional_info && err.message <> " - " <> additional_info) || err.message

              throw(new_err)
            rescue
              _ ->
                raise HTTPError, err.message
            end
          else
            raise HTTPError, err.message
          end
      end

    Jason.decode!(d)["url"]
  end

  @doc """
      HuggingFace git-based system, used for models, datasets, and spaces.
        Call HF API to delete a whole repo.
        CAUTION(this is irreversible).
  """
  def delete_repo(name, token \\ nil, organization \\ "", repo_type \\ "") do
    {json, path, token} =
      prepare_json_for_repos_cmd("delete", name, token, organization, repo_type)

    r =
      Requests.auth_delete(
        path,
        token,
        [{"content-type", "application/json"}],
        Jason.encode!(json)
      )

    Requests.raise_for_status(r)
  end

  defp get_valid_token(token) do
    {:ok, token} = if token === nil, do: HfFolder.get_token(), else: {:ok, token}

    unless token !== "" do
      raise ArgumentError,
            "You need to provide a `token` or be logged in to Hugging Face with `huggingface-cli login`."
    else
      if !is_valid_token?(token) do
        raise ArgumentError, "Invalid token passed!"
      end
    end

    token
  end

  defp prepare_json_for_repos_cmd(cmd, name, token, organization, repo_type, kwargs \\ "") do
    path = "#{@initial_state.endpoint}/api/repos/#{cmd}"
    token = get_valid_token(token)
    checked_name = repo_type_and_id_from_hf_id(name)

    if repo_type !== "" and elem(checked_name, 0) != "" and repo_type != elem(checked_name, 0),
      do:
        raise(
          ArgumentError,
          "Passed `repo_type` and found `repo_type` are not the same (#{repo_type}, #{elem(checked_name, 0)}).  Please make sure you are expecting the right type of repository to exist."
        )

    if organization !== "" and elem(checked_name, 1) != "" and repo_type != elem(checked_name, 1),
      do:
        raise(
          ArgumentError,
          "Passed `organization` and `name` organization are not the same (#{organization}, #{elem(checked_name, 1)}). Please either include the organization in only `name` or the `organization` parameter, such as `api.create_repo(#{elem(checked_name, 0)}, organization=#{organization})` or `api.create_repo(#{elem(checked_name, 1)}/#{elem(checked_name, 2)})`"
        )

    repo_type = (elem(checked_name, 0) != "" && elem(checked_name, 0)) || repo_type
    organization = (elem(checked_name, 1) != "" && elem(checked_name, 1)) || organization
    name = elem(checked_name, 2)

    if repo_type not in Constants.repo_types(),
      do: raise(ArgumentError, "Invalid repo type: #{inspect(repo_type)}")

    json = %{name: name, organization: organization}
    json = (kwargs != "" && Map.merge(json, kwargs)) || json
    {(repo_type != "" && Map.merge(json, %{type: repo_type})) || json, path, token}
  end

  @doc """
        Update the visibility setting of a repository.
  """
  def update_repo_visibility(name, private, token \\ nil, organization \\ "", repo_type \\ "") do
    token = get_valid_token(token)
    namespace = (organization == "" && whoami(token)["name"]) || organization

    path_prefix =
      "#{@initial_state.endpoint}/api/" <>
        if repo_type != "" and repo_type in Map.keys(Constants.repo_types_url_prefixes()),
          do: Constants.repo_types_url_prefixes()[repo_type],
          else: ""

    path = "#{path_prefix}#{namespace}/#{name}/settings"
    json = %{private: private}

    r =
      Requests.auth_put(
        path,
        token,
        [{"content-type", "application/json"}],
        [:with_body],
        Jason.encode!(json)
      )

    Requests.raise_for_status(r)
  end

  def upload_file(
        path_or_fileobj,
        path_in_repo,
        repo_id,
        token \\ nil,
        repo_type \\ "",
        revision \\ "main"
      ) do
    # TODO: Use it?? identical_ok \\ false) do
    if repo_type not in Constants.repo_types(),
      do: raise(ArgumentError, "Invalid repo type: #{inspect(repo_type)}")

    token = get_valid_token(token)

    unless is_binary(path_or_fileobj),
      do: raise(ArgumentError, "path_or_fileobj must be a path to a file or a binary")

    if not (path_in_repo =~ @remote_filepath_regex),
      do:
        raise(
          ArgumentError,
          "Invalid path_in_repo '#{path_in_repo}'. Not matching: #{inspect(@remote_filepath_regex)}"
        )

    repo_type =
      if repo_type in Map.keys(Constants.repo_types_url_prefixes()) do
        Constants.repo_types_url_prefixes()[repo_type] <> repo_id
      else
        repo_type
      end

    path = "#{@initial_state.endpoint}/api/#{repo_id}/upload/#{revision}/#{path_in_repo}"

    datastream =
      if String.printable?(path_or_fileobj) do
        {resp, file} = File.open(Path.expand(path_or_fileobj), [:read])
        unless resp == :ok, do: raise(ArgumentError, "Could not find file: #{path_or_fileobj}")
        IO.binread(file, :all)
      else
        path_or_fileobj
      end

    r = Requests.auth_post(path, token, [], [:with_body], datastream)
    d = Requests.raise_for_status(r)
    # TODO: Add hf_hub_url (so, download) functionalities??
    Jason.decode!(d)["url"]
  end

  def delete_file(
        path_in_repo,
        repo_id,
        token \\ nil,
        repo_type \\ "",
        revision \\ "main"
      ) do
    if repo_type not in Constants.repo_types(),
      do: raise(ArgumentError, "Invalid repo type: #{inspect(repo_type)}")

    token = get_valid_token(token)

    if not (path_in_repo =~ @remote_filepath_regex),
      do:
        raise(
          ArgumentError,
          "Invalid path_in_repo '#{path_in_repo}'. Not matching: #{inspect(@remote_filepath_regex)}"
        )

    repo_type =
      if repo_type in Map.keys(Constants.repo_types_url_prefixes()) do
        Constants.repo_types_url_prefixes()[repo_type] <> repo_id
      else
        repo_type
      end

    path = "#{@initial_state.endpoint}/api/#{repo_id}/delete/#{revision}/#{path_in_repo}"
    r = Requests.auth_delete(path, token, [], [])
    Requests.raise_for_status(r)
  end

  # TODO: Add upload_file, delete_file
end
