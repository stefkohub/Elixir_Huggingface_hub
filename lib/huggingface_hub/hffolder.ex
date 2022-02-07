defmodule Huggingface_hub.HfFolder do
  require Logger

  @path_token Path.expand("~/.huggingface/token")
  def path_token, do: @path_token 

  @doc """
        Save token, creating folder as needed.
  """
  def save_token(token, path_token \\ @path_token) do
    File.mkdir_p!(Path.dirname(path_token))
    File.open(path_token, [:read, :write], fn f ->
      IO.write(f, token)
    end)
  end

  @doc """
    Get token or None if not existent.
  """
  def get_token(path_token \\ @path_token) do
    try do
      File.open(path_token, [:read], fn f ->
        IO.read(f, :all)
      end)
    catch 
      _ -> Logger.info("Cannot read the file #{path_token}")
    end
  end

  @doc """
    Delete token. Do not fail if token does not exist.
  """
  def delete_token(path_token \\ @path_token) do
    try do
      File.rm(path_token)
    catch
      _ -> Logger.info("Cannot remove the file #{path_token}")
    end
  end

end
