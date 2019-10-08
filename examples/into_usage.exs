File.rm("files.zip")

iodata =
  "*.*"
  |> Path.wildcard()
  |> Enum.map(fn path -> {Path.basename(path), File.read!(path)} end)
  |> Enum.into(Zap.new())
  |> Zap.to_iodata()

File.write!("files.zip", iodata, [:binary, :raw])
