# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :cli,
  cookie:
    :erlang.apply(
      fn ->
        if String.contains?(System.cwd!(), "apps") do
          String.trim(File.read!(Enum.join(["../../", "COOKIE"])))
        else
          String.trim(File.read!(Enum.join([System.cwd!(), "/COOKIE"])))
        end
        |> :erlang.binary_to_atom(:utf8)
      end,
      []
    )
