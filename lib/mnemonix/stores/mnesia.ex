defmodule Mnemonix.Stores.Mnesia do
  @moduledoc """
  A `Mnemonix.Store` that uses a Mnesia table to store state.

  Before using, your current node should be part of a Mnesia schema
  and the Mnesia application must have been started.

      iex> {:ok, store} = Mnemonix.Stores.Mnesia.start_link
      iex> Mnemonix.put(store, "foo", "bar")
      iex> Mnemonix.get(store, "foo")
      "bar"
      iex> Mnemonix.delete(store, "foo")
      iex> Mnemonix.get(store, "foo")
      nil
  """

  defmodule Exception do
    defexception [:message]
  end

  use Mnemonix.Store.Behaviour

  alias Mnemonix.Store

  @doc """
  Creates a Mnesia table to store state in.

  If the table specified already exists, it will use that instead.

  ## Options

  - `table:` Name of the table to use, will be created if it doesn't exist.

    *Default:* `#{__MODULE__ |> Inspect.inspect(%Inspect.Opts{})}.Table`

  - `transactional`: Whether or not to perform transactional reads or writes.

    *Allowed:* `:reads | :writes | :both | nil`

    *Default:* `:both`

  - `initial:` A map of key/value pairs to ensure are set on the table at boot.

    *Default:* `%{}`

  The rest of the options are passed into `:dets.open_file/2` verbaitm, except
  for `type:`, which will always be `:set`.
  """
  @spec setup(Mnemonix.Store.options)
    :: {:ok, state :: term} | {:stop, reason :: any}
  def setup(opts) do
    {table, opts} = Keyword.get_and_update(opts, :table, fn _ -> :pop end)
    table = if table, do: table, else: Module.concat(__MODULE__, Table)

    options = opts
    |> Keyword.put(:type, :set)
    |> Keyword.put(:attributes, [:key, :value])

    case :mnesia.create_table(table, options) do
      {:atomic, :ok} -> {:ok, table}
      {:aborted, {:already_exists, ^table}} -> {:ok, table}
      {:aborted, reason} -> {:stop, reason}
    end
  end

  @doc false
  @spec serialize_key(Mnemonix.key, Mnemonix.Store.t)
    :: serialized_key :: term | no_return
  def serialize_key(key, _store) do
    key
  end

  @doc false
  @spec serialize_value(Mnemonix.value, Mnemonix.Store.t)
    :: serialized_value :: term | no_return
  def serialize_value(value, _store) do
    value
  end

  @doc false
  @spec deserialize_key(serialized_key :: term, Mnemonix.Store.t)
    :: Mnemonix.key :: term | no_return
  def deserialize_key(serialized_key, _store) do
    serialized_key
  end

  @doc false
  @spec deserialize_value(serialized_value :: term, Mnemonix.Store.t)
    :: Mnemonix.value :: term | no_return
  def deserialize_value(serialized_value, _store) do
    serialized_value
  end

  @spec delete(Mnemonix.Store.t, Mnemonix.key)
    :: {:ok, Mnemonix.Store.t} | Mnemonix.Store.Behaviour.exception
  def delete(store = %Store{state: table}, key) do
    with :ok <- :mnesia.dirty_delete(table, key) do
      {:ok, store}
    end
  end

  @spec fetch(Mnemonix.Store.t, Mnemonix.key)
    :: {:ok, Mnemonix.Store.t, {:ok, Mnemonix.value} | :error} | Mnemonix.Store.Behaviour.exception
  def fetch(store = %Store{state: table}, key) do
    case :mnesia.dirty_read(table, key) do
      [{^table, ^key, value} | []] -> {:ok, store, {:ok, value}}
      []                           -> {:ok, store, :error}
      other                        -> {:raise, Exception, [reason: other]}
    end
  end

  @spec put(Mnemonix.Store.t, Mnemonix.key, Store.value)
    :: {:ok, Mnemonix.Store.t} | Mnemonix.Store.Behaviour.exception
  def put(store = %Store{state: table}, key, value) do
    with :ok <- :mnesia.dirty_write({table, key, value}) do
      {:ok, store}
    end
  end

end
