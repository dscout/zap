defmodule ZapTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  doctest Zap

  property "any sequence of binary data composes a valid zip archive" do
    check all(entries <- nonempty(list_of(tuple({name(), data()})))) do
      zap = Enum.into(entries, Zap.new())

      assert Zap.bytes(zap) > 0

      zap
      |> Zap.to_iodata()
      |> verify_zipinfo()
    end
  end

  describe "Inspect" do
    test "customizing the inspect output" do
      zap =
        Zap.new()
        |> Zap.entry("a.txt", "aaaa")
        |> Zap.entry("b.txt", "bbbb")
        |> Zap.entry("c.txt", "cccc")

      assert inspect(zap) == ~s(#Zap<["c.txt", "b.txt", "a.txt"]>)
    end
  end

  defp name do
    binary(min_length: 1, max_length: 128)
  end

  defp data do
    binary(min_length: 1)
  end

  defp verify_zipinfo(data) do
    assert {:ok, comment_and_files} = :zip.table(IO.iodata_to_binary(data))

    file_count =
      comment_and_files
      |> Enum.map(&elem(&1, 0))
      |> Enum.count(fn kind -> kind == :zip_file end)

    assert file_count >= 1
  end
end
