use Mix.Config
require Logger

try do
  import_config "dev.secret.exs"
rescue
  e in Code.LoadError ->
    Logger.debug("Expected to load `dev.secret.exs`, but failed to load: #{e.message}")
end
