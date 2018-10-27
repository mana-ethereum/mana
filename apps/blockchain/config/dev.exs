use Mix.Config
require Logger

try do
  import_config "dev.secret.exs"
rescue
  e in Code.LoadError ->
    Logger.error("Expected to load `dev.secret.exs`, but failed to load: #{e.message}")
end
