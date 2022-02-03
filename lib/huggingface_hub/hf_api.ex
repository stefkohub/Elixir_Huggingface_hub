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

  @doc """
        Call HF API to sign in a user and get a token if credentials are valid.
        Outputs: token if credentials are valid
        Throws: requests.exceptions.HTTPError if credentials are invalid
  """
  def login(state, username, password) do
    # TODO: Add Logging
    # logging.error(
    #        "HfApi.login: This method is deprecated in favor of `set_access_token`."
    #    )
    #
    path = "#{state.endpoint}/api/login"
    params = Jason.encode!(%{username: username, password: password})
    r = Requests.post(path, [{"content-type", "application/json"}], [:with_body], params)
    d = Jason.decode!(Requests.raise_for_status(r))
    Shared.write_to_credential_store(username, password)
    d.token
  end

  @doc """
      Call HF API to know "whoami".
        Args:
            token (``str``, `optional`):
                Hugging Face token. Will default to the locally saved token if not provided.
  """
  def whoami(state, token \\ nil) do
    token = if token === nil, do: HfFolder.get_token(), else: token
    unless token !== nil do
      raise ArgumentError, "You need to pass a valid `token` or login by using `huggingface-cli login`"
    end
    path = "#{state.endpoint}/api/whoami-v2"
    r = Requests.get(path, [{"authorization", "Bearer #{token}"}],[:with_body])
    try do
      Requests.raise_for_status(r)
    catch
      HTTPError -> raise """
        Invalid user token. If you didn't pass a user token, make sure you are properly logged in by
        executing huggingface-cli login, and if you did pass a user token, double-check it's correct.
      """
    end
    Jason.encode!(r)
  end

  @doc """
    Call HF API to log out.
        Args:
            token (``str``, `optional`):
                Hugging Face token. Will default to the locally saved token if not provided.

  """
  def logout(state, token \\ nil) do
    Logging.error("This method is deprecated in favor of unset_access_token.")
    token = if token === nil, do: HfFolder.get_token(), else: token
    unless token !== nil do
      raise ArgumentError, "You need to pass a valid `token` or login by using `huggingface-cli login`"
    end
    username = whoami(state, token).name
    Shared.erase_from_credential_store(username)

    path = "#{state.endpoint}/api/logout"
    r = Requests.get(path, [{"authorization", "Bearer #{token}"}],[:with_body])
    try do
      Requests.raise_for_status(r)
    catch
      HTTPError -> raise """
        Invalid user token. If you didn't pass a user token, make sure you are properly logged in by
        executing huggingface-cli login, and if you did pass a user token, double-check it's correct.
      """
    end
  end

  def set_access_token(access_token), do: Shared.write_to_credential_store(@username_placeholder, access_token)

  def unset_access_token(), do: Shared.erase_from_credential_store(@username_placeholder)

  def get_model_tags(state) do
    path = "#{state.endpoint}/api/models-tags-by-type"
    r = Requests.get(path, [], [])
    Requests.raise_for_status(r)
    d = Jason.decode(r)
    ModelTags.modelTags(d)
  end
end
