defmodule ZapTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest Zap

  property "any sequence of binary data composes a valid zip archive" do
    check all entries <- nonempty(list_of(tuple({name(), data()}))) do
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

  defp name do
    binary(min_length: 1, max_length: 128)
  end

  defp data do
    binary(min_length: 1)
  end

  defp verify_zipinfo(data) do
    assert {:ok, comment_and_files} = :zip.table(data)
  end
end
