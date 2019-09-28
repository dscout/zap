defmodule ZapTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest Zap

  # properties
  #
  # the number of bytes is always greater than 0
  # the same data is never flushed
  # any sequence of binary can compose a valid zip archive (oracle)
  property "any sequence of binary data composes a valid zip archive" do
    check all entries <- nonempty(list_of(tuple({string(:ascii), binary()}))) do
      # TODO: Implement Collectable
      zap =
        Enum.reduce(entries, Zap.new(), fn {name, data}, zap ->
          Zap.entry(zap, name, data)
        end)

      assert Zap.bytes(zap) > 0

      {zap, flush} = Zap.flush(zap)
      final = Zap.final(zap)

      assert byte_size(flush) > 0
      assert byte_size(final) > 0

      assert Zap.bytes(zap) == 0

      # TODO: use zipinfo to verify things
    end
  end
end
