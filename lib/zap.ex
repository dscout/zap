defmodule Zap do
  @moduledoc """
  Chunkable zip generation.

  ## Glossary

  * LFH (Local File Header) — Included before each file in the archive. The header contains
  details about the name and size of the entry.
  * CDH (Central Directory Header) — The final bits of an archive, this contains summary
  information about the files contained within the archive.

  # We need to keep track of several different things here, right?
  #
  # 1. Entry binary
  # 2. Entry metadata
  # 3. The amount of binary that has been read so far
  #
  # | name | binary | size | read |
  # | ---- | ------ | ---- | ---- |
  # | a    | "abcd" | 4    | 4    |
  # | b    | "efg"  | 3    | 1    |
  # | c    | "ijkl" | 4    | 0    |
  #
  # flush(4) -> "fgij"
  """

  alias Zap.{Directory, Entry}

  @type t :: %__MODULE__{entries: [Entry.t()]}

  defstruct entries: []

  @doc """
  Initialize a new Zap struct.

  The struct is used to accumulate entries, which can then be flushed as parts of a zip file.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Add a named entry to a zap struct.

  ## Example

      Zap.new()
      |> Zap.entry("a.jpg", jpg_data)
      |> Zap.entry("b.png", png_data)
  """
  @spec entry(zap :: t(), name :: binary(), data :: binary()) :: t()
  def entry(%__MODULE__{} = zap, name, data) when is_binary(name) and is_binary(data) do
    %{zap | entries: List.flatten([zap.entries | [Entry.new(name, data)]])}
  end

  @doc """
  Check the total number of un-flushed bytes available.

  ## Example

      iex> Zap.bytes(Zap.new())
      0

      iex> Zap.new()
      ...> |> Zap.entry("a.txt", "a")
      ...> |> Zap.bytes()
      52

      iex> zap = Zap.new()
      ...> zap = Zap.entry(zap, "a.txt", "a")
      ...> {zap, _bytes} = Zap.flush(zap, :all)
      ...> Zap.bytes(zap)
      0
  """
  @spec bytes(zap :: t()) :: non_neg_integer()
  def bytes(%__MODULE__{entries: entries}) do
    Enum.reduce(entries, 0, &(&1.size + &2))
  end

  @doc """
  Output a complete iolist of data from a Zap struct.

  This is a convenient way of combining the output from `flush/1` and `final/1`.

  Though the function is called `to_iodata` it _also_ returns a zap struct because the struct is
  modified when it is flushed.

  ## Example

      iex> Zap.new()
      ...> |> Zap.entry("a.txt", "aaaa")
      ...> |> Zap.entry("b.txt", "bbbb")
      ...> |> Zap.to_iodata()
      ...> |> IO.iodata_length()
      248
  """
  @spec to_iodata(zap :: t()) :: iodata()
  def to_iodata(%__MODULE__{} = zap) do
    {zap, flush} = flush(zap)
    {_ap, final} = final(zap)

    [flush, final]
  end

  @doc """
  Flush a fixed number of bytes from the stored entries.

  Flushing is stateful, meaning the same data won't be flushed on successive calls.

  ## Example

      iex> Zap.new()
      ...> |> Zap.entry("a.txt", "aaaa")
      ...> |> Zap.entry("b.txt", "bbbb")
      ...> |> Zap.flush()
      ...> |> elem(1)
      ...> |> IO.iodata_length()
      110
  """
  @spec flush(zap :: t(), bytes :: pos_integer() | :all) :: {t(), iodata()}
  def flush(%__MODULE__{entries: entries} = zap, bytes \\ :all) do
    {flushed, entries, _} =
      Enum.reduce(entries, {[], [], bytes}, fn entry, {iodata, entries, bytes} ->
        {entry, binary} = Entry.consume(entry, bytes)

        next_bytes =
          cond do
            bytes == :all -> :all
            bytes - byte_size(binary) > 0 -> bytes - byte_size(binary)
            true -> 0
          end

        {[binary | iodata], [entry | entries], next_bytes}
      end)

    {%{zap | entries: Enum.reverse(entries)}, Enum.reverse(flushed)}
  end

  @doc """
  Generate the final CDH (Central Directory Header), required to complete an archive.
  """
  @spec final(zap :: t()) :: {t(), iodata()}
  def final(%__MODULE__{entries: entries} = zap) do
    {zap, Directory.encode(entries)}
  end

  @doc """
  Stream an enumerable of `name`/`data` pairs into a zip structure and emit chunks of zip data.

  The chunked output will be _at least_ the size of `chunk_size`, but they may be much larger. The
  last emitted chunk automatically includes the central directory header, the closing set of
  bytes.

  ## Example

      iex> %{"a.txt" => "aaaa", "b.txt" => "bbbb"}
      ...> |> Zap.into_stream(8)
      ...> |> Enum.to_list()
      ...> |> IO.iodata_to_binary()
      ...> |> :zip.table()
      ...> |> elem(0)
      :ok
  """
  @spec into_stream(enum :: Enumerable.t(), chunk_size :: pos_integer()) :: Enumerable.t()
  def into_stream(enum, chunk_size \\ 1024 * 1024) when is_integer(chunk_size) do
    chunk_fun = fn {name, data}, zap ->
      zap = entry(zap, name, data)

      if bytes(zap) >= chunk_size do
        {zap, flushed} = flush(zap, :all)

        {:cont, flushed, zap}
      else
        {:cont, zap}
      end
    end

    after_fun = fn zap ->
      iodata = to_iodata(zap)

      {:cont, iodata, zap}
    end

    Stream.chunk_while(enum, Zap.new(), chunk_fun, after_fun)
  end

  defimpl Collectable do
    def into(original) do
      fun = fn
        zap, {:cont, {name, data}} -> Zap.entry(zap, name, data)
        zap, :done -> zap
        _zap, :halt -> :ok
      end

      {original, fun}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    alias Inspect.{List, Opts}

    def inspect(zap, opts) do
      opts = %Opts{opts | charlists: :as_lists}

      concat(["#Zap<", List.inspect(names(zap), opts), ">"])
    end

    defp names(%{entries: entries}) do
      entries
      |> Enum.reverse()
      |> Enum.map(& &1.header.name)
    end
  end
end
