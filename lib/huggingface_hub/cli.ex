defmodule HuggingfaceHub.CLI do
  require Logger

  def main(args) do
    args |> parse_args |> do_process
  end

  def parse_args(args) do
    optparseargs = [
      aliases: [u: :user, h: :help, v: :verbose],
      strict: [user: :string, help: :boolean, verbose: :count]
    ]

    # options = [force_raw: false]

    {opts, args, invalid} =
      OptionParser.parse(
        args,
        optparseargs
      )

    if invalid != [] do
      raise "Error in command line. Wrong arguments " <> inspect([invalid])
    end

    cond do
      opts[:help] ->
        :help

      opts[:user] ->
        {:user, opts[:user], args}

      true ->
        IO.puts("Cannot understand the command: #{inspect(args)}, #{inspect(opts)}")
        :help
    end
  end

  # From https://github.com/hexpm/hex/blob/8602339308e68477357807b838280c9d2be0edc1/lib/mix/tasks/hex.ex#L371

  def password_clean(prompt) do
    pid = spawn_link(fn -> loop(prompt) end)
    ref = make_ref()
    value = IO.gets(prompt <> " ")

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)

    String.trim(value)
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        IO.write(:standard_error, "\e[2K\r#{prompt} ")
        loop(prompt)
    end
  end

  def do_process(:help) do
    IO.puts("""
      Usage: huggingface_hub [COMMAND] [OPTIONS] [PARAMS]
      Command Line Interface for Huggingface Hub APIs

      Commands:
        --user        User-related interactions
        --help        This help screen

      Options:
      User-related options
        login         Login into Huggingface hub. Needs at least the username. 
                      Password can be passed as parameter or using stdin
        logout        Logout from Huggingface hub. Needs the username
        whoami        Get useful information about the logged in user

    """)

    System.halt(0)
  end

  def do_process({:user, "login", args}) do
    username = Enum.at(args, 0)
    password = Enum.at(args, 1)

    unless username do
      raise "Login requires at least username"
    end

    password = (password == nil && password_clean("password>")) || password

    token =
      try do
        HuggingfaceHub.login(username, password)
      rescue
        err in HTTPError ->
          IO.puts("Error in login: #{err.message} -- code: #{err.status_code}")
          IO.puts("Possible details: #{err.trace}")
          System.halt(1)
      end

    Huggingface_hub.Hf_api.set_access_token(token)
    Huggingface_hub.HfFolder.save_token(token)
    IO.puts("Login successful")
    IO.puts("Your token has been saved to #{Huggingface_hub.HfFolder.path_token()}")
    Huggingface_hub.Shared.currently_setup_credential_helpers()
  end

  def do_process({:user, "logout", args}) do
    Logger.error("This method is deprecated in favor of `unset_access_token`.")
    maybe_token = Enum.at(args, 0)

    token =
      if maybe_token do
        maybe_token
      else
        unless {:ok, t} = Huggingface_hub.HfFolder.get_token(),
          do:
            raise(
              ArgumentError,
              "You need to pass a valid `token` or login by using `huggingface-cli login`"
            )

        t
      end

    HuggingfaceHub.logout(token)
  end

  def do_process({:user, "whoami", _args}) do
    IO.puts(inspect(HuggingfaceHub.whoami()))
  end
end
