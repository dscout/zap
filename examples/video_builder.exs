write_fun = &File.write!("videos.zip", &1, [:append, :binary, :raw])

paths = ~w(
  /Users/parker/Downloads/SampleVideo_1280x720_1mb.mp4
  /Users/parker/Downloads/SampleVideo_1280x720_2mb.mp4
  /Users/parker/Downloads/SampleVideo_1280x720_5mb.mp4
  /Users/parker/Downloads/SampleVideo_1280x720_10mb.mp4
  /Users/parker/Downloads/SampleVideo_1280x720_20mb.mp4
)

File.rm("videos.zip")

paths
|> Stream.map(fn path -> {Path.basename(path), File.read!(path)} end)
|> Zap.stream_chunks(1024 * 1024)
|> Stream.each(fn _ -> IO.inspect(:erlang.memory()[:binary]) end)
|> Stream.each(write_fun)
|> Stream.run()
