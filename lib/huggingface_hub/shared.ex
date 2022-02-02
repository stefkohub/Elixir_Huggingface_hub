defmodule Huggingface_hub.Shared do
  alias Huggingface_hub.Constants

  def write_to_credential_store(username, password) do
    input_username = "username=#{String.downcase(username)}"
    input_password = "password=#{password}"
    myport = Port.open({:spawn, "git credential-store store"}, [])
    Port.command myport, "url=#{Constants.endpoint}\n#{input_username}\n#{input_password}\n\n"
    Port.close(myport)
  end

  @doc """
    Reads the credential store relative to huggingface.co. If no `username` is specified, will read the first
    entry for huggingface.co, otherwise will read the entry corresponding to the username specified.
    The username returned will be all lowercase.
  """
  def read_from_credential_store(username \\ "") do
    standard_input = "url=#{Constants.endpoint}\n"
    standard_input = username != "" && standard_input <> "username=#{String.downcase(username)}\n\n" || standard_input<>"\n"
    myport = Port.open({:spawn, "git credential-store get"}, [])
    Port.command myport, standard_input
    msg = receive do
      {^myport, {:data, result}} ->
        result
      after 
        1000 -> raise "Cannot get response from git in 1 second"
    end
    [username, password | _] = String.split(to_string(msg), "\n")
    [ Enum.at(String.split(username, "="), 1), Enum.at(String.split(password, "="), 1) ]
  end

  def erase_from_credential_store(username \\ "") do
    standard_input = "url=#{Constants.endpoint}\n"
    standard_input = username != "" && standard_input <> "username=#{String.downcase(username)}\n\n" || standard_input<>"\n"
    myport = Port.open({:spawn, "git credential-store erase"}, [])
    Port.command myport, standard_input
  end
end
