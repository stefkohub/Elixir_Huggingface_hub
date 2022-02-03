defmodule HfFolder do
  require Logger

  @path_token Path.expand("~/.huggingface/token")

  @doc """
        Save token, creating folder as needed.
  """
  def save_token(cls, token) do
    File.mkdir_p!(Path.dirname(cls.path_token))
    File.open(cls.path_token, [:read, :write], fn f ->
      IO.write(f, token)
    end)
  end

  @doc """
    Get token or None if not existent.
  """
  def get_token(cls) do
    try do
      File.open(cls.path_token, [:read], fn f ->
        IO.read(f, :all)
      end)
    catch 
      _ -> Logger.info("Cannot read the file #{cls.path_token}")
    end
  end

  @doc """
    Delete token. Do not fail if token does not exist.
  """
  def delete_token(cls) do
    try do
      File.rm(cls.path_token)
    catch
      _ -> Logger.info("Cannot remove the file #{cls.path_token}")
    end
  end

end
