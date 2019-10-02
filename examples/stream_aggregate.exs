write_fun = &File.write!("streamed.zip", &1, [:append, :binary, :raw])

gener_fun = fn ->
  name =
    ?a..?z
    |> Enum.take_random(10)
    |> to_string()

  data =
    fn -> :crypto.strong_rand_bytes(1024 * 50) end
    |> Stream.repeatedly()
    |> Stream.take(200)
    |> Enum.to_list()
    |> IO.iodata_to_binary()

  {name, data}
end

File.rm("streamed.zip")

gener_fun
|> Stream.repeatedly()
|> Stream.take(20)
|> Zap.stream_chunks(2048)
|> Stream.each(fn _ -> IO.inspect(:erlang.memory()[:binary]) end)
|> Stream.each(write_fun)
|> Stream.run()
