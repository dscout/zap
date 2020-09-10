defmodule Zap.Directory do
  @moduledoc false

  use Bitwise

  alias Zap.Entry

  @context %{frames: [], count: 0, offset: 0, size: 0}
  @comment "Created by Zap"

  @spec encode([Entry.t()]) :: binary()
  def encode([%Entry{} | _] = entries) do
    context = build_context(entries)

    {zip64_record, context} = encode_zip64_record(context)
    {zip64_marker, context} = encode_zip64_marker(context)

    end_frame = <<
      0x06054B50::little-size(32),
      # number of this disk
      0xFFFF::little-size(16),
      # number of the disk w/ ECD
      0xFFFF::little-size(16),
      # total number of entries in this disk
      0xFFFF::little-size(16),
      # total number of entries in the ECD
      0xFFFF::little-size(16),
      # size central directory
      0xFFFFFFFF::little-size(32),
      # offset central directory
      0xFFFFFFFF::little-size(32),
      # comment length
      byte_size(@comment)::little-size(16),
      @comment
    >>

    [Enum.reverse(context.frames), zip64_record, zip64_marker, end_frame]
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

    extra = <<
      # extra tag
      0x0001::little-size(16),
      # size of this extra block
      28::little-size(16),
      # uncompressed size
      entity[:usize]::little-size(64),
      # compressed size
      entity[:csize]::little-size(64),
      # offset of local header
      context[:offset]::little-size(64),
      # number of disk where file starts
      (<<0::little-size(32)>>)
    >>

    frame = <<
      # central file header signature
      0x02014B50::little-size(32),
      # version made by
      52::little-size(16),
      # version needed to extract, with Zip64 support
      45::little-size(16),
      # general purpose bit flag (bit 3: data descriptor, bit 11: utf8 name)
      <<0x0008 ||| 0x0800::little-size(16)>>,
      # compression method
      0::little-size(16),
      # last mod file time
      dos_time(mtime)::little-size(16),
      # last mod date
      dos_date(mtime)::little-size(16),
      # crc-32
      entity[:crc]::little-size(32),
      # compressed size
      0xFFFFFFFF::little-size(32),
      # uncompressed size
      0xFFFFFFFF::little-size(32),
      # file name length
      header[:nsize]::little-size(16),
      # extra field length
      byte_size(extra)::little-size(16),
      # file comment length
      0::little-size(16),
      # disk number start
      0xFFFF::little-size(16),
      # internal file attribute
      0::little-size(16),
      # external file attribute (unix permissions, rw-r--r--)
      (0o10 <<< 12 ||| 0o644) <<< 16::little-size(32),
      # relative offset header
      0xFFFFFFFF::little-size(32),
      # file name
      header.name::binary,
      # extra
      extra::binary
    >>

    %{frame: frame, size: byte_size(frame), offset: header.size + entity.size}
  end

  defp encode_zip64_record(context) do
    frame = <<
      # signature
      0x06064B50::little-size(32),
      # size of zip64 end of central directory record
      44::little-size(64),
      # version made by
      52::little-size(16),
      # version needed to extract
      45::little-size(16),
      # number of this disk
      0::little-size(32),
      # number of the disk with the start of the central directory
      0::little-size(32),
      # total number of entries in the central directory on this disk
      context.count::little-size(64),
      # total number of entries in the central directory
      context.count::little-size(64),
      # size of the central directory
      context.size::little-size(64),
      # offset of start of central directory with respect to the starting disk number
      context.offset::little-size(64)
    >>

    {frame, context}
  end

  defp encode_zip64_marker(context) do
    record_offset = context.offset + IO.iodata_length(context.frames)

    frame = <<
      # signature
      0x07064B50::little-size(32),
      # number of the disk with the start of the zip64 end of central directory
      0::little-size(32),
      # relative offset of the zip64 end of central directory record
      record_offset::little-size(64),
      # total number of disks
      1::little-size(32)
    >>

    {frame, context}
  end

  defp dos_time(time) do
    round(time.second / 2 + (time.minute <<< 5) + (time.hour <<< 11))
  end

  defp dos_date(time) do
    round(time.day + (time.month <<< 5) + ((time.year - 1980) <<< 9))
  end
end
