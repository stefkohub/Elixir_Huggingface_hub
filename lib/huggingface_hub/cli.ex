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

      true -> raise "Cannot understand the command: #{inspect args}, #{inspect opts}"
        # opt -> Keyword.merge(options, opt)
    end

    # cond do
    #  Keyword.get(opts, :help) -> :help
    #  Keyword.get(opts, :model) -> Keyword.get(opts, :model)
    #  Keyword.get(opts, :force_raw) -> :force_raw
    #  true -> :help
    # end
  end

  def do_process(:help) do
    IO.puts("""
    optional arguments:
    -h, --help          show this help message and exit
    -r, --force_raw     Force writing raw data instead of converting to actual type. In Elixir it boosts performances.
    -m MODEL, --model MODEL
                        [yolov3-tiny|yolov3|yolov3-spp|yolov4-tiny|yolov4|yolov4-csp|yolov4x-mish]-[{dimension}],
                        where {dimension} could be either a single number (e.g. 288, 416, 608) or 2 numbers, WxH (e.g.
                        416x256)
    """)

    System.halt(0)
  end

  def do_process({:user, "login", args}) do
    username = Enum.at(args, 0)
    password = Enum.at(args, 1)

    unless username && password do
      raise "Login requires username and password"
    end

    token =
      try do
        # Huggingface_hub.Hf_api.login(username, password)
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
        unless t = Huggingface_hub.HfFolder.get_token(),
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
    IO.puts inspect HuggingfaceHub.whoami
  end
end
