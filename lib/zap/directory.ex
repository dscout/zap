defmodule Zap.Directory do
  @moduledoc false

  use Bitwise

  alias Zap.Entry

  @context %{frames: [], count: 0, offset: 0, size: 0}
  @comment "Created by Zap"

  @spec encode([Entry.t()]) :: binary()
  def encode([%Entry{} | _] = entries) do
    context = build_context(entries)

    frame = <<
      0x06054B50::little-size(32),
      # number of this disk
      0::little-size(16),
      # number of the disk w/ ECD
      0::little-size(16),
      # total number of entries in this disk
      context[:count]::little-size(16),
      # total number of entries in the ECD
      context[:count]::little-size(16),
      # size central directory
      context[:size]::little-size(32),
      # offset central directory
      context[:offset]::little-size(32),
      # comment length
      byte_size(@comment)::little-size(16),
      @comment
    >>

    IO.iodata_to_binary([context.frames, frame])
  end

  defp build_context(entries) do
    Enum.reduce(entries, @context, fn entry, acc ->
      header = encode_header(acc, entry)

      acc
      |> Map.update!(:frames, &[header.frame | &1])
      |> Map.update!(:count, &(&1 + 1))
      |> Map.update!(:offset, &(&1 + header.offset))
      |> Map.update!(:size, &(&1 + header.size))
    end)
  end

  defp encode_header(context, %{header: header, entity: entity}) do
    mtime = NaiveDateTime.from_erl!(:calendar.local_time())

    frame = <<
      # central file header signature
      0x02014B50::little-size(32),
      # version made by
      52::little-size(16),
      # version to extract
      20::little-size(16),
      # general purpose flag
      0x0800::little-size(16),
      # compression method
      0::little-size(16),
      # last mod file time
      dos_time(mtime)::little-size(16),
      # last mod date
      dos_date(mtime)::little-size(16),
      # crc-32
      entity[:crc]::little-size(32),
      # compressed size
      entity[:csize]::little-size(32),
      # uncompressed size
      entity[:usize]::little-size(32),
      # file name length
      header[:nsize]::little-size(16),
      # extra field length
      0::little-size(16),
      # file comment length
      0::little-size(16),
      # disk number start
      0::little-size(16),
      # internal file attribute
      0::little-size(16),
      # external file attribute (unix permissions, rw-r--r--)
      ((0o10 <<< 12 ||| (0o644 &&& 0o7777)) <<< 16)::little-size(32),
      # relative offset header
      context[:offset]::little-size(32),
      # file name
      header[:name]::binary
    >>

    %{frame: frame, size: byte_size(frame), offset: header.size + entity.size}
  end

  defp dos_time(time) do
    round(time.second / 2 + (time.minute <<< 5) + (time.hour <<< 11))
  end

  defp dos_date(time) do
    round(time.day + (time.month <<< 5) + ((time.year - 1980) <<< 9))
  end
end
