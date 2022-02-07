defmodule HTTPError do
  defexception [:message, :status_code, :trace]

  @impl true
  def exception(value) do
    trace = "#{inspect(value)}"
    {msg, status_code} = try do
      {:ok, {status_code, _, msg}} = value
      {msg, status_code}
    rescue
      _ -> {trace, -1}
    end
    %HTTPError{message: msg, status_code: status_code, trace: trace}
  end
end

defmodule Huggingface_hub.Hackney do
  @moduledoc """
    Implementation of HTTP(s) methods to interact with endpoints
    (partially from: https://github.com/lau/tzdata/http_client/hackney.ex)
  """

  @behaviour Huggingface_hub.HTTPClient


  if Code.ensure_loaded?(:hackney) do
    @impl true
    @doc """
      HTTP GET method
    """
    def get(url, headers, options) do
      with {:ok, status, headers, client_ref} <- :hackney.get(url, headers, "", options),
           {:ok, body} <- :hackney.body(client_ref) do
        {:ok, {status, headers, body}}
      end
    end

    @impl true
    @doc """
      HTTP POST method
    """
    def post(url, headers, options, params) do
      with {:ok, status, headers, body} <- :hackney.post(url, headers, params, options) do
        {:ok, {status, headers, body}}
      end
    end

    @impl true
    @doc """
      Raise an error if http status code is not 200 or any other error occurred
    """
    def raise_for_status(req) do
      try do
        {:ok, {code, _, resp}} = req
        unless code == 200, do: raise HTTPError, req
        resp
      rescue
        # TODO: Maybe in that case it is better to raise another kind of exeption?
        _ -> raise HTTPError, req
      end
    end
  else
    @message """
    missing :hackney dependency
    It is required a HTTP client in order to interact with huggingface.co
    In order to use the built-in adapter based on Hackney HTTP client, add the
    following to your mix.exs dependencies list:
        {:hackney, "~> 1.0"}
    See README for more information.
    """

    @impl true
    def get(_url, _headers, _options) do
      raise @message
    end

    @impl true
    def post(_url, _headers, _options, _params) do
      raise @message
    end

    @impl true
    def raise_for_status(_req) do
      raise @message
    end
  end
end
