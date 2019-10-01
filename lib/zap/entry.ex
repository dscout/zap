defmodule Zap.Entry do
  @moduledoc false

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

    IO.inspect([bytes, byte_size(take), byte_size(keep)])

    {%{entry | binary: keep, size: byte_size(keep)}, take}
  end

  defp encode_header(name) when is_binary(name) do
    nsize = byte_size(name)

    frame = <<
      # local file header signature
      0x04034B50::size(32)-little,
      # version needed to extract
      0x0A::size(16)-little,
      # general purpose bit flag
      8::size(16)-little,
      # compression method
      0::size(16)-little,
      # last mod time
      0::size(16)-little,
      # last mod date
      0::size(16)-little,
      # crc-32
      0::size(32)-little,
      # compressed size
      0::size(32)-little,
      # uncompressed size
      0::size(32)-little,
      # file name length
      nsize::size(16)-little,
      # extra field length
      0::size(16)-little,
      name::binary
    >>

    {frame, %{size: byte_size(frame), name: name, nsize: nsize}}
  end

  defp encode_entity(data) when is_binary(data) do
    crc = :erlang.crc32(data)
    size = byte_size(data)

    frame = <<
      # local file entry signature
      0x08074B50::size(32)-little,
      # crc-32 for the entity
      crc::size(32)-little,
      # compressed size, just the size since we aren't compressing
      size::size(32)-little,
      # uncompressed size
      size::size(32)-little
    >>

    {frame, %{crc: crc, size: size + byte_size(frame), usize: size, csize: size}}
  end
end
