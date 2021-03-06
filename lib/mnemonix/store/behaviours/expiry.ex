defmodule Mnemonix.Store.Behaviours.Expiry do
  @moduledoc false

  @optional_callbacks setup_expiry: 1
  @callback setup_expiry(Mnemonix.Store.t)
    :: {:ok, Mnemonix.Store.t} | {:error, reason}
      when reason: :normal | :shutdown | {:shutdown, term} | term

  @optional_callbacks expire: 3
  @callback expire(Mnemonix.Store.t, Mnemonix.key, Mnemonix.Features.Bump.ttl)
    :: {:ok, Mnemonix.Store.t} | Mnemonix.Store.Behaviour.exception

  @optional_callbacks persist: 2
  @callback persist(Mnemonix.Store.t, Mnemonix.key)
    :: {:ok, Mnemonix.Store.t} | Mnemonix.Store.Behaviour.exception

  @optional_callbacks put_and_expire: 4
  @callback put_and_expire(Mnemonix.Store.t, Mnemonix.key, Mnemonix.value, Mnemonix.Features.Bump.ttl)
    :: {:ok, Mnemonix.Store.t} | Mnemonix.Store.Behaviour.exception

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote __MODULE__

      alias Mnemonix.Store.Expiry

      @doc false
      def setup_expiry(store = %Mnemonix.Store{opts: opts}) do
        with {:ok, engine} <- Expiry.Engine.start_link(opts) do
          {:ok, %{store | expiry: engine}}
        end
      end
      defoverridable setup_expiry: 1

      @doc false
      def expire(store, key, ttl) do
        with :ok <- Expiry.Engine.expire(store, key, ttl) do
          {:ok, store}
        end
      end
      defoverridable expire: 3

      @doc false
      def persist(store, key) do
        with :ok <- Expiry.Engine.persist(store, key) do
          {:ok, store}
        end
      end
      defoverridable persist: 2

      @doc false
      def put_and_expire(store, key, value, ttl) do
        with {:ok, store} <- put(store, key, value),
             {:ok, store} <- expire(store, key, ttl),
        do: {:ok, store}
      end
      defoverridable put_and_expire: 4

    end
  end

end
