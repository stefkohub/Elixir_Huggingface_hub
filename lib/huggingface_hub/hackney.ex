defmodule HTTPError do
  defexception [:message]

  @impl true
  def exception(value) do
    msg = "#{inspect(value)}"
    %HTTPError{message: msg}
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
      with {:ok, status, headers} <- :hackney.post(url, headers, params, options) do
        {:ok, {status, headers}}
      end
    end

    @impl true
    @doc """
      Raise an error if an error has occurred during the process.
    """
    def raise_for_status(req) do
      resp = try do
        {:ok, {code, _, resp}} = req
        unless code == 200, do: raise HTTPError, req
        resp
      catch
        _ -> raise HTTPError, req
      end
      resp
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
  end
end
