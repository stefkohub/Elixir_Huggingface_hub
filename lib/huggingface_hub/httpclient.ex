defmodule Huggingface_hub.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client
  Partially taken from: https://github.com/lau/tzdata/lib/tzdata/http_client.ex
  """

  @type status() :: non_neg_integer()

  @type headers() :: [{header_name :: String.t(), header_value :: String.t()}]

  @type body() :: binary()

  @type param() :: %{}

  @type response() :: [{}]

  @type option() :: {:follow_redirect, boolean}

  @callback auth_get(
              url :: String.t(),
              bearer_token :: String.t(),
              headers(),
              qs :: String.t(),
              options :: [option]
            ) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback get(url :: String.t(), headers(), qs :: String.t(), options :: [option]) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback auth_post(
              url :: String.t(),
              bearer_token :: String.t(),
              headers(),
              options :: [option],
              params :: [param]
            ) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback post(url :: String.t(), headers(), options :: [option], params :: [param]) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback auth_put(
              url :: String.t(),
              bearer_token :: String.t(),
              headers(),
              options :: [option],
              params :: [param]
            ) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback put(url :: String.t(), headers(), options :: [option], params :: [param]) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback auth_delete(
              url :: String.t(),
              bearer_token :: String.t(),
              headers(),
              params :: [param]
            ) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback delete(url :: String.t(), headers(), params :: [param]) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback raise_for_status(response :: response()) ::
              {:ok, {response()}}

  # @callback head(url :: String.t(), headers(), options :: [option]) ::
  #            {:ok, {status(), headers()}} | {:error, term()}
end
