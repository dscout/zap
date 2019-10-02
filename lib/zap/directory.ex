defmodule Zap.Directory do
  @moduledoc false

  alias Zap.Entry

  @context %{frames: [], count: 0, offset: 0, size: 0}

  @spec encode([Entry.t()]) :: binary()
  def encode([%Entry{} | _] = entries) do
    context = build_context(entries)

    frame =
      <<
        0x06054B50::size(32)-little,
        # number of this disk
        0::size(16)-little,
        # number of the disk w/ ECD
        0::size(16)-little,
        # total number of entries in this disk
        context[:count]::size(16)-little,
        # total number of entries in the ECD
        context[:count]::size(16)-little,
        # size central directory
        context[:size]::size(32)-little,
        # offset central directory
        context[:offset]::size(32)-little,
        0::size(16)-little
      >>

    IO.iodata_to_binary([Enum.reverse(context.frames), frame])
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
    frame = <<
      # central file header signature
      0x02014B50::size(32)-little,
      # version made by
      20::size(16)-little,
      # version to extract
      0x0A::size(16)-little,
      # general purpose flag
      8::size(16)-little,
      # compression method
      0::size(16)-little,
      # last mod file time
      0::size(16)-little,
      # last mod file date
      0::size(16)-little,
      # crc-32
      entity[:crc]::size(32)-little,
      # compressed size
      entity[:csize]::size(32)-little,
      # uncompressed size
      entity[:usize]::size(32)-little,
      # file name length
      header[:nsize]::size(16)-little,
      # extra field length
      0::size(16)-little,
      # file comment length
      0::size(16)-little,
      # disk number start
      0::size(16)-little,
      # internal file attribute
      0::size(16)-little,
      # external file attribute
      0::size(32)-little,
      # relative offset header
      context[:offset]::size(32)-little
    >>

    %{
      frame: [frame, header.name],
      size: byte_size(frame) + header.nsize,
      offset: header.size + entity.size
    }
  end
end
