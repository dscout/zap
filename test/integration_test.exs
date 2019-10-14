defmodule IntegrationTest do
  use ExUnit.Case

  test "expanding files in a generated archive" do
    File.mkdir("tmp")

    entries = %{"a.txt" => "apple", "b.txt" => "mango", "c.txt" => "peach"}

    iodata =
      entries
      |> Enum.into(Zap.new())
      |> Zap.to_iodata()

    File.write!("tmp/files.zip", iodata, [:binary, :raw])

    System.cmd("unzip", ["files.zip"], cd: "tmp")

    assert Path.wildcard("tmp/*.txt") == ["tmp/a.txt", "tmp/b.txt", "tmp/c.txt"]

    for {file, data} <- entries do
      assert File.read!(Path.join("tmp", file)) == data
    end
  after
    File.rm_rf("tmp")
  end
end
