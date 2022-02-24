defmodule HTTPError do
  defexception [:message, :status_code, :trace]

  @impl true
  def exception(value) do
    trace = "#{inspect(value)}"

    {msg, status_code} =
      try do
        {_, {status_code, _, msg}} = value
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
    (partially from: https://github.com/lau/tzdata/lib/tzdata/http_client/hackney.ex)
  """

  @available_functions [
    auth_get: 5,
    get: 4,
    auth_post: 5,
    post: 4,
    auth_put: 5,
    put: 4,
    auth_delete: 4,
    delete: 3,
    raise_for_status: 1
  ]
  @behaviour Huggingface_hub.HTTPClient

  if Code.ensure_loaded?(:hackney) do
    @doc """
      HTTP GET method
    """
    @impl true
    def auth_get(url, bearer, headers \\ [], qs \\ [], options \\ []) do
      get(url, [{"authorization", "Bearer #{bearer}"}] ++ headers, qs, options)
    end

    @impl true
    def get(url, headers \\ [], qs \\ [], options \\ []) do
      url =
        if qs != [] do
          Enum.map(qs, fn {key, val} ->
            if is_list(val) do
              encoded =
                List.duplicate(to_string(key) <> "[]", Enum.count(val))
                |> then(fn x -> List.zip([x, val]) end)
                |> URI.encode_query()

              encoded
            else
              URI.encode_query([{key, val}])
            end
          end)
          |> Enum.join("&")
          |> then(fn x -> url <> "?" <> x end)
        else
          url
        end

      with {:ok, status, headers, client_ref} <- :hackney.get(url, headers, "", options),
           {:ok, body} <- :hackney.body(client_ref) do
        {:ok, {status, headers, body}}
      end
    end

    @impl true
    @doc """
      HTTP POST method
    """
    def auth_post(url, bearer, headers, options, params) do
      post(url, [{"authorization", "Bearer #{bearer}"}] ++ headers, options, params)
    end

    @impl true
    def post(url, headers, options, params) do
      with {:ok, status, headers, body} <- :hackney.post(url, headers, params, options) do
        {:ok, {status, headers, body}}
      end
    end

    @impl true
    @doc """
      HTTP PUT method
    """
    def auth_put(url, bearer, headers, options, params) do
      put(url, [{"authorization", "Bearer #{bearer}"}] ++ headers, options, params)
    end

    @impl true
    def put(url, headers, options, params) do
      with {:ok, status, headers, body} <- :hackney.put(url, headers, params, options) do
        {:ok, {status, headers, body}}
      end
    end

    @impl true
    def auth_delete(url, bearer, headers, params) do
      delete(url, [{"authorization", "Bearer #{bearer}"}] ++ headers, params)
    end

    @impl true
    def delete(url, headers, params) do
      with {:ok, status, headers, client_ref} <- :hackney.delete(url, headers, params),
           {:ok, body} <- :hackney.body(client_ref) do
        {:ok, {status, headers, body}}
      end
    end

    @impl true
    @doc """
      Raise an error if http status code is not 200 or any other error occurred
    """
    def raise_for_status(req) do
      maybe_raise =
        try do
          {:ok, {code, headers, resp}} = req

          if code != 200 do
            respobj = Jason.decode!(resp)

            message =
              cond do
                400 <= code and code <= 500 ->
                  "#{code} Client Error: #{respobj["error"]}"

                500 <= code and code <= 600 ->
                  "#{code} Server Error: #{respobj["error"]}"

                true ->
                  "#{code} Generic Error: #{respobj["error"]}"
              end

            message =
              (respobj["url"] != nil && "#{message} for url: #{respobj["url"]}") || message

            # respobj = Map.merge(respobj, %{"error" => message})
            {:error, {code, headers, message}}
          else
            {:ok, resp}
          end
        rescue
          # TODO: Maybe in that case it is better to raise another kind of exception?
          err in _ ->
            {:error, err}
        end

      case maybe_raise do
        {:ok, resp} -> resp
        {:error, err} -> raise HTTPError, {:error, err}
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

    for {f, arity} <- @available_functions do
      args = Macro.generate_arguments(arity, __MODULE__)
      @impl true
      def unquote(f)(unquote_splicing(args)) do
        raise @message
      end
    end
  end
end
