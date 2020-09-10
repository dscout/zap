iodata =
  ~w(CHANGELOG.md README.md LICENSE.txt)
  |> Map.new(fn name -> {name, File.read!(name)} end)
  |> Enum.into(Zap.new())
  |> Zap.to_iodata()

File.write!("test_files.zip", iodata, [:binary, :raw])
