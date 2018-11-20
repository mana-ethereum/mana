defmodule Blockchain.Account do
  @moduledoc """
  Represents the account state,
  as defined in Section 4.1 of the Yellow Paper
  """

  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.TrieStorage
  alias Blockchain.Account.{Address, Storage}

  @empty_keccak Keccak.kec(<<>>)
  @empty_trie Trie.empty_trie_root_hash()

  # State defined in Section 4.1 of the Yellow Paper:
  # nonce: σ_n
  # balance: σ_b
  # storage_root: σ_s
  # code_hash: σ_c
  defstruct nonce: 0,
            balance: 0,
            storage_root: @empty_trie,
            code_hash: @empty_keccak

  @type t :: %__MODULE__{
          nonce: integer(),
          balance: EVM.Wei.t(),
          storage_root: EVM.trie_root(),
          code_hash: MerklePatriciaTree.Trie.key()
        }

  @doc """
  Checks whether or not an account is a non-contract account.
  If the codeHash field is the Keccak-256 hash of the empty string, then the
  node represents a simple account, sometimes referred to as a “non-contract”
  account. This is defined in the latter part of Section 4.1 of the Yellow Paper.

  ## Examples

      iex> Blockchain.Account.is_simple_account?(%Blockchain.Account{})
      true

      iex> Blockchain.Account.is_simple_account?(%Blockchain.Account{code_hash: <<0x01, 0x02>>})
      false

      iex> Blockchain.Account.is_simple_account?(%Blockchain.Account{code_hash: <<197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112>>})
      true
  """
  @spec is_simple_account?(t) :: boolean()
  def is_simple_account?(acct) do
    acct.code_hash == @empty_keccak
  end

  @doc """
  Encodes an account such that it can be represented in RLP encoding.
  This is defined as Eq.(10) `p` in the Yellow Paper.

  ## Examples

      iex> Blockchain.Account.serialize(%Blockchain.Account{nonce: 5, balance: 10, storage_root: <<0x00, 0x01>>, code_hash: <<0x01, 0x02>>})
      [5, 10, <<0x00, 0x01>>, <<0x01, 0x02>>]

      iex> Blockchain.Account.serialize(%Blockchain.Account{})
      [
        0,
        0,
        <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
        <<197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112>>
      ]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(account) do
    [
      account.nonce,
      account.balance,
      account.storage_root,
      account.code_hash
    ]
  end

  @doc """
  Decodes an account from an RLP encodable structure.
  This is defined as Eq.(10) `p` in the Yellow Paper (reversed).

  ## Examples

      iex> Blockchain.Account.deserialize([<<5>>, <<10>>, <<0x00, 0x01>>, <<0x01, 0x02>>])
      %Blockchain.Account{nonce: 5, balance: 10, storage_root: <<0x00, 0x01>>, code_hash: <<0x01, 0x02>>}

      iex> Blockchain.Account.deserialize([<<0>>, <<0>>, <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>, <<197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112>>])
      %Blockchain.Account{}
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      nonce,
      balance,
      storage_root,
      code_hash
    ] = rlp

    %Blockchain.Account{
      nonce: :binary.decode_unsigned(nonce),
      balance: :binary.decode_unsigned(balance),
      storage_root: storage_root,
      code_hash: code_hash
    }
  end

  @doc """
  Loads an account from an address, as defined in Eq.(9), Eq.(10), and Eq.(12)
  of the Yellow Paper.

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> MerklePatriciaTree.Trie.update_key(<<0x01::160>> |> ExthCrypto.Hash.Keccak.kec(), ExRLP.encode([5, 6, <<1>>, <<2>>]))
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{nonce: 5, balance: 6, storage_root: <<0x01>>, code_hash: <<0x02>>}

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> MerklePatriciaTree.Trie.update_key(<<0x01::160>> |> ExthCrypto.Hash.Keccak.kec(), nil)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      nil

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      nil
  """
  @spec get_account(TrieStorage.t(), Address.t()) :: t | nil
  def get_account(state, address) do
    account = TrieStorage.get_key(state, Keccak.kec(address))

    case account do
      nil ->
        nil

      encoded_account ->
        encoded_account
        |> ExRLP.decode()
        |> deserialize()
    end
  end

  @doc """
  Checks for an empty code hash and a zero nonce. This is the equivalent of any
  empty account check regardless of whether the account has a balance. This
  check is needed when an account hides money in one of it's contract addresses
  and later creates a contract to get the money out. This technique is
  documented as `Quirk #1 - hiding in plain sight` in the [Ethereum quirks and
  vulns](http://swende.se/blog/Ethereum_quirks_and_vulns.html) blog post.
  """
  @spec uninitialized_contract?(t()) :: boolean()
  def uninitialized_contract?(account) do
    account.nonce == 0 && account.code_hash == @empty_keccak
  end

  @doc """
  Checks if an account is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(account) do
    account.nonce == 0 && account.balance == 0 &&
      (account.code_hash == Trie.empty_trie_root_hash() || is_simple_account?(account))
  end

  @doc """
  Helper function to load multiple accounts.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.update_key(MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db()), <<0x01::160>> |> ExthCrypto.Hash.Keccak.kec(), ExRLP.encode([5, 6, <<1>>, <<2>>]))
      iex> Blockchain.Account.get_accounts(state, [<<0x01::160>>, <<0x02::160>>])
      [
        %Blockchain.Account{nonce: 5, balance: 6, storage_root: <<0x01>>, code_hash: <<0x02>>},
        nil
      ]
  """
  @spec get_accounts(EVM.state(), [Address.t()]) :: [t | nil]
  def get_accounts(state, addresses) do
    for address <- addresses, do: get_account(state, address)
  end

  @doc """
  Stores an account at a given address. This function handles serializing
  the account, encoding it to RLP and placing into the given state trie.

  ## Examples

      iex> state = Blockchain.Account.put_account(MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db()), <<0x01::160>>, %Blockchain.Account{nonce: 5, balance: 6, storage_root: <<0x01>>, code_hash: <<0x02>>})
      iex> MerklePatriciaTree.Trie.get_key(state, <<0x01::160>> |> ExthCrypto.Hash.Keccak.kec()) |> ExRLP.decode
      [<<5>>, <<6>>, <<0x01>>, <<0x02>>]
  """
  @spec put_account(EVM.state(), Address.t(), t) :: EVM.state()
  def put_account(state, address, account) do
    encoded_account =
      account
      |> serialize()
      |> ExRLP.encode()

    TrieStorage.update_key(state, Keccak.kec(address), encoded_account)
  end

  @doc """
  Completely removes an account from the world state.
  This is used, for instance, after a selfdestruct.
  This is defined from Eq.(71) and Eq.(80) in the Yellow Paper.

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.del_account(<<0x01::160>>)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      nil

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.del_account(<<0x01::160>>)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      nil
  """
  @spec del_account(EVM.state(), Address.t()) :: EVM.state()
  def del_account(state, address) do
    account = get_account(state, address)

    case account do
      nil ->
        state

      _acc ->
        TrieStorage.remove_key(state, Keccak.kec(address))
    end
  end

  @doc """
  Gets and updates an account based on a given input
  function `fun`. Account passed to `fun` will be blank
  instead of nil if account doesn't exist.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> Blockchain.Account.update_account(state, <<0x01::160>>, fn (acc) -> {%{acc | balance: acc.balance + 5}, state} end)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 15}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> {_state, before_acct, after_acct} = Blockchain.Account.update_account(state, <<0x01::160>>, fn (acc) -> {%{acc | balance: acc.balance + 5}, state} end, true)
      iex> before_acct.balance
      10
      iex> after_acct.balance
      15

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> Blockchain.Account.update_account(state, <<0x01::160>>, fn (acc) -> {%{acc | nonce: acc.nonce + 1}, state} end)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{nonce: 1}
  """
  @spec update_account(EVM.state(), Address.t(), (t -> t), boolean()) ::
          EVM.state() | {EVM.state(), t, t}
  def update_account(state, address, fun, return_accounts \\ false) do
    account = get_account(state, address) || %__MODULE__{}
    {updated_account, updated_state} = fun.(account)

    updated_state = put_account(updated_state, address, updated_account)

    if return_accounts do
      {updated_state, account, updated_account}
    else
      updated_state
    end
  end

  @doc """
  Simple helper function to increment a nonce value.

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{nonce: 10})
      iex> state
      ...> |> Blockchain.Account.increment_nonce(<<0x01::160>>)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{nonce: 11}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{nonce: 10})
      iex> { _state, before_acct, after_acct } = Blockchain.Account.increment_nonce(state, <<0x01::160>>, true)
      iex> before_acct.nonce
      10
      iex> after_acct.nonce
      11
  """
  @spec increment_nonce(EVM.state(), Address.t(), boolean()) :: EVM.state() | {EVM.state(), t, t}
  def increment_nonce(state, address, return_accounts \\ false) do
    update_account(
      state,
      address,
      fn acct ->
        {%{acct | nonce: acct.nonce + 1}, state}
      end,
      return_accounts
    )
  end

  @doc """
  Simple helper function to adjust wei in an account. Wei may be positive (to
  add wei) or negative (to remove it). This function will raise if we attempt to
  reduce wei in an account to less than zero.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.add_wei(<<0x01::160>>, 13)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 23}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.add_wei(<<0x01::160>>, -3)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 7}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.add_wei(<<0x01::160>>, -13)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      ** (RuntimeError) wei reduced to less than zero
  """
  @spec add_wei(EVM.state(), Address.t(), EVM.Wei.t()) :: EVM.state()
  def add_wei(state, address, delta_wei) do
    update_account(state, address, fn acct ->
      updated_balance = acct.balance + delta_wei

      if updated_balance < 0, do: raise("wei reduced to less than zero")

      {%{acct | balance: updated_balance}, state}
    end)
  end

  @doc """
  Even simpler helper function to adjust wei in an account negatively. Wei may
  be positive (to subtract wei) or negative (to add it). This function will
  raise if we attempt to reduce wei in an account to less than zero.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.dec_wei(<<0x01::160>>, 3)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 7}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.dec_wei(<<0x01::160>>, 13)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      ** (RuntimeError) wei reduced to less than zero

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.dec_wei(<<0x01::160>>, -3)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 13}
  """
  @spec dec_wei(EVM.state(), Address.t(), EVM.Wei.t()) :: EVM.state()
  def dec_wei(state, address, delta_wei), do: add_wei(state, address, -1 * delta_wei)

  @doc """
  Helper function for transferring eth for one account to another.
  This handles the fact that a new account may be shadow-created if
  it receives eth. See Section 8, Eq.(100-104) of the Yellow Paper.

  The Yellow Paper assumes this function will always succeed (as the checks
  occur before this function is called), but we'll check just in case this
  function is not properly called. The only case will be if the sending account
  is nil or has an insufficient balance, but we add a few extra checks just in
  case.

  **Note**: transferring value to an empty account still adds value to said
  account, even though it's effectively a zombie.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.put_account(<<0x02::160>>, %Blockchain.Account{balance: 5})
      iex> {:ok, state} = Blockchain.Account.transfer(state, <<0x01::160>>, <<0x02::160>>, 3)
      iex> {Blockchain.Account.get_account(state, <<0x01::160>>), Blockchain.Account.get_account(state, <<0x02::160>>)}
      {%Blockchain.Account{balance: 7}, %Blockchain.Account{balance: 8}}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> {:ok, state} = Blockchain.Account.transfer(state, <<0x01::160>>, <<0x02::160>>, 3)
      iex> {Blockchain.Account.get_account(state, <<0x01::160>>), Blockchain.Account.get_account(state, <<0x02::160>>)}
      {%Blockchain.Account{balance: 7}, %Blockchain.Account{balance: 3}}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> Blockchain.Account.transfer(state, <<0x01::160>>, <<0x02::160>>, 12)
      {:error, "sender account insufficient wei"}

      iex> Blockchain.Account.transfer(MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db()), <<0x01::160>>, <<0x02::160>>, -3)
      {:error, "wei transfer cannot be negative"}
  """
  @spec transfer(EVM.state(), Address.t(), Address.t(), EVM.Wei.t()) ::
          {:ok, EVM.state()} | {:error, String.t()}
  def transfer(state, from, to, wei) do
    # TODO: Decide if we want to waste the cycles to pull
    # the account information when `add_wei` will do that itself.
    from_account = get_account(state, from)

    cond do
      wei < 0 ->
        {:error, "wei transfer cannot be negative"}

      from_account == nil ->
        {:error, "sender account does not exist"}

      from_account.balance < wei ->
        {:error, "sender account insufficient wei"}

      true ->
        {:ok,
         state
         |> add_wei(from, -1 * wei)
         |> add_wei(to, wei)}
    end
  end

  @doc """
  Performs transfer but raises instead of returning if an error occurs.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.put_account(<<0x02::160>>, %Blockchain.Account{balance: 5})
      iex> state = Blockchain.Account.transfer!(state, <<0x01::160>>, <<0x02::160>>, 3)
      iex> {Blockchain.Account.get_account(state, <<0x01::160>>), Blockchain.Account.get_account(state, <<0x02::160>>)}
      {%Blockchain.Account{balance: 7}, %Blockchain.Account{balance: 8}}
  """
  @spec transfer!(EVM.state(), Address.t(), Address.t(), EVM.Wei.t()) :: EVM.state()
  def transfer!(state, from, to, wei) do
    case transfer(state, from, to, wei) do
      {:ok, state} -> state
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Puts code into a given account.

  **Note**: we need to store the `code_hash` outside of the contract itself and
  only store the KEC of the code_hash. See Section 4.1 under `codeHash` in the
  Yellow Paper.

  All such code fragments are contained in the
  state database under their corresponding hashes for later retrieval.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_code(<<0x01::160>>, <<1, 2, 3>>)
      iex> Blockchain.Account.get_account(state, <<0x01::160>>)
      %Blockchain.Account{code_hash: <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30,
                                        32, 147, 34, 13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168,
                                        59, 253, 92, 146, 57>>}
      iex> MerklePatriciaTree.DB.get(state.db, ExthCrypto.Hash.Keccak.kec(<<1, 2, 3>>))
      {:ok, <<1, 2, 3>>}
  """
  @spec put_code(TrieStorage.t(), Address.t(), EVM.MachineCode.t()) :: TrieStorage.t()
  def put_code(state, contract_address, machine_code) do
    kec = Keccak.kec(machine_code)

    new_state = TrieStorage.put_raw_key!(state, kec, machine_code)

    update_account(state, contract_address, fn acct ->
      {%{acct | code_hash: kec}, new_state}
    end)
  end

  @doc """
  Returns the machine code associated with the account at the given address.
  This will return nil if the contract has no associated code (i.e. it is a
  simple account).

  We may return `:not_found`, indicating that we were not able to find the given
  code hash in the state trie.

  Alternatively, we will return `{:ok, machine_code}` where `machine_code` may
  be the empty string `<<>>`.

  **Note**: "it is assumed that the client will have stored the pair  (KEC(I_b),
  I_b) at some point prior in order to make the determination of Ib feasible"

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.machine_code(<<0x01::160>>)
      {:ok, <<>>}

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_code(<<0x01::160>>, <<1, 2, 3>>)
      ...> |> Blockchain.Account.machine_code(<<0x01::160>>)
      {:ok, <<1, 2, 3>>}
  """
  @spec machine_code(TrieStorage.t(), Address.t() | t()) :: {:ok, binary()} | :not_found
  def machine_code(state, contract_address) when is_binary(contract_address) do
    # TODO: Do we have a standard for default account values
    account = get_account(state, contract_address) || %__MODULE__{}

    machine_code(state, account)
  end

  def machine_code(state, account) do
    case account.code_hash do
      @empty_keccak ->
        {:ok, <<>>}

      code_hash ->
        case TrieStorage.get_raw_key(state, code_hash) do
          {:ok, machine_code} when is_binary(machine_code) -> {:ok, machine_code}
          _ -> :not_found
        end
    end
  end

  @doc """
  Stores a value in the storage root of an account. This
  is defined in Section 4.1 under **storageRoot** in the
  Yellow Paper.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> updated_state = Blockchain.Account.put_storage(state, <<01::160>>, 5, 9)
      iex> Blockchain.Account.get_storage(updated_state, <<01::160>>, 5)
      {:ok, 9}
  """
  @spec put_storage(TrieStorage.t(), Address.t() | {Address.t(), t()}, integer(), integer()) ::
          {t(), TrieStorage.t()}
  def put_storage(state, address, key, value) when is_binary(address) do
    account = get_account(state, address) || %__MODULE__{}

    put_storage(state, {address, account}, key, value)
  end

  def put_storage(state, {address, account}, key, value) do
    {updated_storage_trie, updated_trie} = Storage.put(state, account.storage_root, key, value)

    root_hash = TrieStorage.root_hash(updated_storage_trie)
    updated_account = %{account | storage_root: root_hash}

    updated_state = put_account(updated_trie, address, updated_account)

    {updated_account, updated_state}
  end

  @spec remove_storage(EVM.state(), Address.t(), integer()) :: EVM.state()
  def remove_storage(state, address, key) do
    update_account(state, address, fn acct ->
      {updated_storage_trie, updated_trie} = Storage.remove(state, acct.storage_root, key)
      root_hash = TrieStorage.root_hash(updated_storage_trie)

      {%{acct | storage_root: root_hash}, updated_trie}
    end)
  end

  @doc """
  Gets a value from storage root of an account.
  See Section 4.1 under **storageRoot** from the Yellow Paper.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> updated_state = Blockchain.Account.put_storage(state, <<01::160>>, 5, 9)
      iex> Blockchain.Account.get_storage(updated_state, <<01::160>>, 5)
      {:ok, 9}

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> Blockchain.Account.get_storage(state, <<02::160>>, 5)
      :account_not_found

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> updated_state = Blockchain.Account.put_storage(state, <<01::160>>, 5, 9)
      iex> Blockchain.Account.get_storage(updated_state, <<01::160>>, 55)
      :key_not_found
  """
  @spec get_storage(MerklePatriciaTree.Trie.t(), Address.t() | t() | nil, integer()) ::
          {:ok, any()} | :account_not_found | :key_not_found
  def get_storage(state, address, key) when is_binary(address) do
    account = get_account(state, address)

    get_storage(state, account, key)
  end

  def get_storage(state, account, key) do
    case account do
      nil ->
        :account_not_found

      account ->
        case Storage.fetch(state, account.storage_root, key) do
          nil -> :key_not_found
          value -> {:ok, value |> :binary.decode_unsigned()}
        end
    end
  end

  @doc """
  Sets the balance of an account to zero.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 100})
      iex> state
      ...> |> Blockchain.Account.clear_balance(<<0x01::160>>)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 0}
  """
  @spec clear_balance(EVM.state(), Address.t()) :: EVM.state()
  def clear_balance(state, address) do
    update_account(state, address, fn acct ->
      {%{acct | balance: 0}, state}
    end)
  end

  @doc """
  Resets an account to the basic struct.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 100, code_hash: "abc"})
      iex> state
      ...> |> Blockchain.Account.reset_account(<<0x01::160>>)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{}
  """
  @spec reset_account(TrieStorage.t(), Address.t()) :: EVM.state()
  def reset_account(state, address) do
    put_account(state, address, %__MODULE__{})
  end

  @spec empty_keccak() :: binary()
  def empty_keccak do
    @empty_keccak
  end

  @spec empty_trie() :: binary()
  def empty_trie do
    @empty_trie
  end
end
