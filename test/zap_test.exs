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

  # Testing with `unzip -t` generates output like this:
  #
  # Archive:  tmp.zip
  # Created by Zap
  #     testing: a.txt                    OK
  #     testing: b.txt                    OK
  #     testing: c.txt                    OK
  # No errors detected in compressed data of files.zip.
  defp verify_zipinfo(iodata) do
    File.write!("tmp.zip", iodata, [:binary, :raw])

    {output, 0} = System.cmd("unzip", ["-t", "tmp.zip"])

    output
    |> String.split("\n", trim: true)
    |> Enum.drop(1)
    |> Enum.each(&verify_healthy/1)
  after
    File.rm_rf("tmp.zip")
  end

  defp verify_healthy("Created by Zap"), do: :ok
  defp verify_healthy("    testing: " <> entry), do: assert entry =~ "OK"
  defp verify_healthy("No errors detected in compressed data" <> _), do: :ok
end
