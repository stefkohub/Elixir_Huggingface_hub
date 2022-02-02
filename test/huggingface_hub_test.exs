defmodule HuggingfaceHubTest do
  use ExUnit.Case
  doctest HuggingfaceHub

  test "greets the world" do
    assert HuggingfaceHub.hello() == :world
  end
end
