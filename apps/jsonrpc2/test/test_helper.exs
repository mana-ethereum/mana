Enum.map([:ranch, :hackney], &Application.ensure_all_started/1)
ExUnit.start()
