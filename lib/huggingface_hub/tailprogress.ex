defmodule Huggingface_hub.TailProgress do
  use GenServer, restart: :transient
  require Logger

  @moduledoc """
        
  """

  def start_link(filename, func) do
    GenServer.start_link(__MODULE__, [filename, func])
  end

  def init([filename, func]) do
    Process.flag(:trap_exit, true)
    pid = self()

    {:ok,
     %{pid: pid, file: nil, filename: filename, func: func, latest_output: nil, end_loop: false}}
  end

  def handle_call(:latest, _from, state) do
    t =
      if state.file != nil do
        IO.read(state.file, :line)
      else
        ""
      end

    state = Map.merge(state, %{latest_output: t})
    {:reply, t, state}
  end

  def handle_info(:end_loop, state) do
    {:noreply, %{state | end_loop: true}}
  end

  def handle_info({:file_open, file}, state) do
    {:noreply, %{state | file: file}}
  end

  def tail(pid) do
    if :sys.get_state(pid).file != nil do
      res = GenServer.call(pid, :latest)

      if res != :eof do
        to_call = :sys.get_state(pid).func
        to_call.(res)
      else
        Process.sleep(1000)
      end
    else
      # File is not yet ready to be read
      maybe_file = File.open(:sys.get_state(pid).filename)

      case maybe_file do
        {:ok, file} -> send(pid, {:file_open, file})
        _ -> Process.sleep(1000)
      end
    end

    :sys.get_state(pid).end_loop == false && tail(pid)
  end

  def endtail(pid) do
    send(pid, :end_loop)
  end
end

