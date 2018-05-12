ExUnit.configure(timeout: :infinity)
ExUnit.start()

{:ok, files} = File.ls("./test/support")

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)
