use Mix.Config
require Logger

try do
  import_config "dev.secret.exs"
rescue
  _e in Code.LoadError ->
    # Tried to load `dev.secret.exs`, but failed to load
    :ok
end
