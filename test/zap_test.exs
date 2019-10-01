defmodule ZapTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest Zap

  property "any sequence of binary data composes a valid zip archive" do
    check all entries <- nonempty(list_of(tuple({string(:ascii), binary()}))) do
      zap = Enum.into(entries, Zap.new())

      assert Zap.bytes(zap) > 0

      {zap, flush} = Zap.flush(zap)
      final = Zap.final(zap)

      assert byte_size(flush) > 0
      assert byte_size(final) > 0

      assert Zap.bytes(zap) == 0

      verify_zipinfo(flush <> final)
    end
  end

  describe "Inspect" do
    test "customizing the inspect output" do
      zap =
        Zap.new()
        |> Zap.entry("a.txt", "aaaa")
        |> Zap.entry("b.txt", "bbbb")
        |> Zap.entry("c.txt", "cccc")

      assert inspect(zap) == ~s(#Zap<["a.txt", "b.txt", "c.txt"]>)
    end
  end

  defp verify_zipinfo(data) do
    path = "archive.zip"

    File.write!("archive.zip", data)

    {_response, exit_code} = System.cmd("zipinfo", [path])

    assert exit_code == 0
  after
    File.rm("archive.zip")
  end
end
