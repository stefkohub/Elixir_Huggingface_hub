
defmodule Huggingface_hub.RunCommand do
  @moduledoc """

     Kudos to: @tonyc for his
        https://github.com/tonyc/elixir_ports_example/blob/master/lib/trap_process_crash.ex
  """

  use GenServer, restart: :transient
  require Logger

  @timeout 5000
  @git_lfs_logfile (System.fetch_env("GIT_LFS_PROGRESS") != :error and
                      System.fetch_env("GIT_LFS_PROGRESS") != "" &&
                      System.fetch_env("GIT_LFS_PROGRESS")) ||
                     "/home/stefano/ElixirML/Elixir_Huggingface_hub/git_lfs.log"

  @cmd :system_cmd

  def progress(line) do
    [_state, _file_progress, byte_progress, filename] = String.split(line)
    [current_bytes, total_bytes] = String.split(byte_progress, "/")

    format = [
      left: "(#{filename}) ",
      suffix: :bytes,
      width: 80
    ]

    ProgressBar.render(String.to_integer(current_bytes), String.to_integer(total_bytes), format)
  end

  def git_progressbar(cwd \\ ".", cmdstring, env \\ []) do
    git_proc = Task.async(fn -> git(cwd, cmdstring, env) end)

    {:ok, pid} =
      Huggingface_hub.TailProgress.start_link(
        @git_lfs_logfile,
        &progress/1
      )

    Task.async(fn -> Huggingface_hub.TailProgress.tail(pid) end)
    result = Task.await(git_proc, :infinity)
    Huggingface_hub.TailProgress.endtail(pid)
    result
  end

  def git(cwd \\ ".", cmdstring, env \\ []) do
    env = Enum.concat([{"GIT_LFS_PROGRESS", @git_lfs_logfile}], env)
    unquote(@cmd)("git", cwd: cwd, cmdstring: cmdstring, env: env)
  end

  def gitlfs(cwd \\ ".", cmdstring, env \\ []) do
    env = Enum.concat([{"GIT_LFS_PROGRESS", @git_lfs_logfile}], env)
    unquote(@cmd)("git-lfs", cwd: cwd, cmdstring: cmdstring, env: env)
  end

  def system_cmd(cmd, args) do
    [cwd: cwd, cmdstring: cmdstring, env: env] = args
    opts = String.split(cmdstring)

    command_path = System.find_executable(cmd)

    case System.cmd(command_path, opts, cd: Path.expand(cwd), env: env, stderr_to_stdout: true) do
      {output, exit_status} -> %{exit_status: exit_status, stdout: output}
      any -> raise "Error in system_cmd: #{inspect(any)}"
    end
  end

  # cwd, cmdstring, env \\ []) do
  def port_cmd(cmd, args) do
    [cwd: cwd, cmdstring: cmdstring, env: env] = args
    opts = String.split(cmdstring)

    command_path = System.find_executable(cmd)
    unless command_path !== nil, do: raise("Can't find executable")

    {:ok, pid} = start_link(command_path, cwd: Path.expand(cwd), opts: opts, env: env)
    exit_status = exit_status(pid)
    stdout = :sys.get_state(pid).latest_output
    %{exit_status: exit_status, stdout: stdout}
  end

  def start_link(command, opts) do
    GenServer.start_link(__MODULE__, [command: command] ++ opts)
  end

  def init(command: command, cwd: cwd, opts: args, env: env) do
    Process.flag(:trap_exit, true)

    bin_env = for {key, val} <- env, do: {to_charlist(key), to_charlist(val)}
    port =
      Port.open(
        {:spawn_executable, command},
        [:binary, :exit_status, :stderr_to_stdout, args: args, cd: Path.absname(cwd), env: bin_env]
      )

    Port.monitor(port)

    {:ok, %{port: port, latest_output: nil, exit_status: nil}}
  end

  def terminate(reason, %{port: port} = state) do
    Logger.info(
      "**TERMINATE: #{inspect(reason)}. This is the last chance to clean up after this process."
    )

    Logger.info("Final state: #{inspect(state)}")

    port_info = Port.info(port)
    os_pid = port_info[:os_pid]

    Logger.warn("Orphaned OS process: #{os_pid}")

    :normal
  end

  def handle_call(:latest_output, _, state) do
    receiver = state.port

    c =
      receive do
        {^receiver, {:data, res}} -> res
      after
        @timeout -> raise "No output from command after #{@timeout}ms"
      end

    {:reply, c, state}
  end

  def handle_call(:exit_status, _, state) do
    receiver = state.port

    c =
      receive do
        {^receiver, {:exit_status, res}} -> res
      after
        @timeout -> raise "No output from command after #{@timeout}ms"
      end

    {:reply, c, state}
  end

  # This callback handles data incoming from the command's STDOUT
  def handle_info({port, {:data, text_line}}, %{port: port} = state) do
    # Logger.info "Data: #{inspect text_line}"
    {:noreply, %{state | latest_output: String.trim(text_line)}}
  end

  # This callback tells us when the process exits
  def handle_info({_, {:exit_status, status}}, %{port: _} = state) do
    new_state = %{state | exit_status: status}

    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :port, _port, :normal}, state) do
    # Logger.info "Handled :DOWN message from port: #{inspect port}"
    {:noreply, state}
  end

  def handle_info({:EXIT, _port, :normal}, state) do
    # Logger.info "handle_info: EXIT from port: #{inspect port}"
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  def status(pid) do
    res = :sys.get_state(pid)
    res.exit_status
  end

  def exit_status(pid) do
    GenServer.call(pid, :exit_status)
  end

  def is_done(pid) do
    status(pid) != nil
  end

  def failed(pid) do
    exit_status(pid) > 0
  end

  def stdout(pid) do
    GenServer.call(pid, :latest_output)
  end
end

