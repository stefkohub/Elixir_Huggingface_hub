defmodule Huggingface_hub.Hf_api do
  # import Logging

  alias Huggingface_hub.Constants

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
    r = 
  end


end
