# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :cli,
  cookie:
    apply(
      fn ->
        cookie =
          if String.contains?(System.cwd!(), "apps") do
            String.trim(File.read!(Path.join(["../../", "COOKIE"])))
          else
            String.trim(File.read!(Path.join([System.cwd!(), "COOKIE"])))
          end

        :erlang.binary_to_atom(cookie, :utf8)
      end,
      []
    )
