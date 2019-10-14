defmodule Zap.Entry do
  @moduledoc false

  use Bitwise

  @type header :: %{
          size: non_neg_integer(),
          name: String.t(),
          nsize: non_neg_integer()
        }

  @type entity :: %{
          crc: pos_integer(),
          size: non_neg_integer(),
          usize: non_neg_integer(),
          csize: non_neg_integer()
        }

  @type t :: %__MODULE__{
          binary: iodata(),
          entity: entity(),
          header: header(),
          size: non_neg_integer()
        }

  defstruct [:binary, :header, :entity, size: 0]

  @spec new(name :: String.t(), data :: binary()) :: t()
  def new(name, data) do
    {hframe, header} = encode_header(name)
    {eframe, entity} = encode_entity(data)

    binary = IO.iodata_to_binary([hframe, data, eframe])

    struct(
      __MODULE__,
      binary: binary,
      header: header,
      entity: entity,
      size: byte_size(binary)
    )
  end

  @spec consume(entry :: t(), bytes :: :all | pos_integer()) :: {t(), binary()}
  def consume(%__MODULE__{size: 0} = entry, _bytes) do
    {entry, ""}
  end

  def consume(%__MODULE__{} = entry, :all) do
    {%{entry | binary: "", size: 0}, entry.binary}
  end

  def consume(%__MODULE__{size: size} = entry, bytes) when bytes >= size do
    {%{entry | binary: "", size: 0}, entry.binary}
  end

  def consume(%__MODULE__{binary: binary, size: size} = entry, bytes) do
    take = binary_part(binary, 0, bytes)
    keep = binary_part(binary, bytes, size - bytes)

    {%{entry | binary: keep, size: byte_size(keep)}, take}
  end

  defp encode_header(name) when is_binary(name) do
    nsize = byte_size(name)
    mtime = NaiveDateTime.from_erl!(:calendar.local_time())

    frame = <<
      # local file header signature
      0x04034B50::little-size(32),
      # version needed to extract
      20::little-size(16),
      # general purpose bit flag
      8::little-size(16),
      # compression method (always 0, we aren't compressing currently)
      0::little-size(16),
      # last mod time
      dos_time(mtime)::little-size(16),
      # last mod date
      dos_date(mtime)::little-size(16),
      # crc-32
      0::little-size(32),
      # compressed size
      0::little-size(32),
      # uncompressed size
      0::little-size(32),
      # file name length
      nsize::little-size(16),
      # extra field length
      0::little-size(16),
      # file name
      name::binary
    >>

    {frame, %{size: byte_size(frame), name: name, nsize: nsize}}
  end

  defp encode_entity(data) when is_binary(data) do
    crc = :erlang.crc32(data)
    size = byte_size(data)

    frame = <<
      # local file entry signature
      0x08074B50::little-size(32),
      # crc-32 for the entity
      crc::little-size(32),
      # compressed size, just the size since we aren't compressing
      size::little-size(32),
      # uncompressed size
      size::little-size(32)
    >>

    {frame, %{crc: crc, size: size + byte_size(frame), usize: size, csize: size}}
  end

  defp dos_time(time) do
    round(time.second / 2 + (time.minute <<< 5) + (time.hour <<< 11))
  end

  defp dos_date(time) do
    round(time.day + (time.month <<< 5) + ((time.year - 1980) <<< 9))
  end
end
