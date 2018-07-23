defmodule Blockchain.Transaction do
  @moduledoc """
  This module encodes the transaction object,
  defined in Section 4.2 of the Yellow Paper.
  We are focused on implementing 𝛶, as defined in Eq.(1).
  """

  alias Blockchain.{Account, Contract, Transaction, MathHelper}
  alias Block.Header
  alias EVM.Gas

  # nonce: T_n
  # gas_price: T_p
  # gas_limit: T_g
  # to: T_t
  # value: T_v
  # v: T_w
  # r: T_r
  # s: T_s
  # init: T_i
  # data: T_d
  defstruct nonce: 0,
            gas_price: 0,
            gas_limit: 0,
            to: <<>>,
            value: 0,
            v: nil,
            r: nil,
            s: nil,
            init: <<>>,
            data: <<>>

  @type t :: %__MODULE__{
          nonce: EVM.val(),
          gas_price: EVM.val(),
          gas_limit: EVM.val(),
          to: EVM.address() | <<_::0>>,
          value: EVM.val(),
          v: Transaction.Signature.hash_v(),
          r: Transaction.Signature.hash_r(),
          s: Transaction.Signature.hash_s(),
          init: EVM.MachineCode.t(),
          data: binary()
        }

  @doc """
  Encodes a transaction such that it can be RLP-encoded.
  This is defined at L_T Eq.(15) in the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.serialize(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"})
      [<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]

      iex> Blockchain.Transaction.serialize(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 8, v: 27, r: 9, s: 10, init: <<1, 2, 3>>})
      [<<5>>, <<6>>, <<7>>, <<>>, <<8>>, <<1, 2, 3>>, <<27>>, <<9>>, <<10>>]

      iex> Blockchain.Transaction.serialize(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 8, v: 27, r: 9, s: 10, init: <<1, 2, 3>>}, false)
      [<<5>>, <<6>>, <<7>>, <<>>, <<8>>, <<1, 2, 3>>]

      iex> Blockchain.Transaction.serialize(%Blockchain.Transaction{ data: "", gas_limit: 21000, gas_price: 20000000000, init: "", nonce: 9, r: 0, s: 0, to: "55555555555555555555", v: 1, value: 1000000000000000000 })
      ["\t", <<4, 168, 23, 200, 0>>, "R\b", "55555555555555555555", <<13, 224, 182, 179, 167, 100, 0, 0>>, "", <<1>>, "", ""]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(tx, include_vrs \\ true) do
    base = [
      tx.nonce |> BitHelper.encode_unsigned(),
      tx.gas_price |> BitHelper.encode_unsigned(),
      tx.gas_limit |> BitHelper.encode_unsigned(),
      tx.to,
      tx.value |> BitHelper.encode_unsigned(),
      input_data(tx)
    ]

    if include_vrs do
      base ++
        [
          BitHelper.encode_unsigned(tx.v),
          BitHelper.encode_unsigned(tx.r),
          BitHelper.encode_unsigned(tx.s)
        ]
    else
      base
    end
  end

  @doc """
  Returns the input data for the transaction. If the transaction is a contract
  creation, then it will return the data in the `init` field. If the transaction
  is a message call transaction, then it will return the data in the `data`
  field.
  """
  @spec input_data(t) :: binary()
  def input_data(tx) do
    if contract_creation?(tx) do
      tx.init
    else
      tx.data
    end
  end

  @doc """
  Decodes a transaction that was previously encoded
  using `Transaction.serialize/1`. Note, this is the
  inverse of L_T Eq.(15) defined in the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.deserialize([<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>])
      %Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}

      iex> Blockchain.Transaction.deserialize([<<5>>, <<6>>, <<7>>, <<>>, <<8>>, <<1, 2, 3>>, <<27>>, <<9>>, <<10>>])
      %Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 8, v: 27, r: 9, s: 10, init: <<1, 2, 3>>}

      iex> Blockchain.Transaction.deserialize(["\t", <<4, 168, 23, 200, 0>>, "R\b", "55555555555555555555", <<13, 224, 182, 179, 167, 100, 0, 0>>, "", <<1>>, "", ""])
      %Blockchain.Transaction{
        data: "",
        gas_limit: 21000,
        gas_price: 20000000000,
        init: "",
        nonce: 9,
        r: 0,
        s: 0,
        to: "55555555555555555555",
        v: 1,
        value: 1000000000000000000
      }
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      nonce,
      gas_price,
      gas_limit,
      to,
      value,
      init_or_data,
      v,
      r,
      s
    ] = rlp

    {init, data} = if to == <<>>, do: {init_or_data, <<>>}, else: {<<>>, init_or_data}

    %__MODULE__{
      nonce: :binary.decode_unsigned(nonce),
      gas_price: :binary.decode_unsigned(gas_price),
      gas_limit: :binary.decode_unsigned(gas_limit),
      to: to,
      value: :binary.decode_unsigned(value),
      init: init,
      data: data,
      v: :binary.decode_unsigned(v),
      r: :binary.decode_unsigned(r),
      s: :binary.decode_unsigned(s)
    }
  end

  @doc """
  Validates the validity of a transaction that is required to be
  true before we're willing to execute a transaction. This is
  specified in Section 6.2 of the Yellow Paper Eq.(65) and Eq.(66).

  TODO: Consider returning a set of reasons, instead of a singular reason.
  """
  @spec valid?(EVM.state(), t, Block.Header.t()) :: :valid | {:invalid, atom()}
  def valid?(state, trx, block_header) do
    g_0 = intrinsic_gas_cost(trx, block_header)
    v_0 = trx.gas_limit * trx.gas_price + trx.value

    result =
      case Transaction.Signature.sender(trx) do
        {:error, _reason} ->
          {:invalid, :invalid_sender}

        {:ok, sender_address} ->
          case Account.get_account(state, sender_address) do
            nil ->
              {:invalid, :missing_account}

            sender_account ->
              {:ok, sender_account}
          end
      end

    with {:ok, sender_account} <- result do
      cond do
        sender_account.nonce != trx.nonce -> {:invalid, :nonce_mismatch}
        g_0 > trx.gas_limit -> {:invalid, :insufficient_intrinsic_gas}
        v_0 > sender_account.balance -> {:invalid, :insufficient_balance}
        trx.gas_limit > Header.available_gas(block_header) -> {:invalid, :over_gas_limit}
        true -> :valid
      end
    end
  end

  @doc """
  Validates the validity of a transaction and then executes it if transaction is valid.
  """
  @spec execute_with_validation(EVM.state(), t, Header.t()) ::
          {EVM.state(), Gas.t(), EVM.SubState.logs()}
  def execute_with_validation(state, tx, block_header) do
    validation_result = valid?(state, tx, block_header)

    with :valid <- validation_result do
      execute(state, tx, block_header)
    end
  end

  @doc """
  Performs transaction execution, as defined in Section 6
  of the Yellow Paper, defined there as 𝛶, Eq.(1) and Eq.(59),
  Eq.(70), Eq.(79) and Eq.(80).

  From the Yellow Paper, T_o is the original transactor, which can differ from the
  sender in the case of a message call or contract creation
  not directly triggered by a transaction but coming from
  the execution of EVM-code.
  """
  @spec execute(EVM.state(), t, Header.t()) :: {EVM.state(), Gas.t(), EVM.SubState.logs()}
  def execute(state, tx, block_header) do
    {:ok, sender} = Transaction.Signature.sender(tx)

    state_0 = begin_transaction(state, sender, tx)

    # sender and originator are the same for transaction execution
    originator = sender
    # stack depth starts at zero for transaction execution
    stack_depth = 0
    # apparent value is the full value for transaction execution
    apparent_value = tx.value
    # gas is equal to what was just subtracted from sender account less intrinsic gas cost
    gas = tx.gas_limit - intrinsic_gas_cost(tx, block_header)

    # TODO: Sender versus originator?
    {state_p, remaining_gas, sub_state} =
      if contract_creation?(tx) do
        params = %Contract.CreateContract{
          state: state_0,
          sender: sender,
          originator: originator,
          available_gas: gas,
          gas_price: tx.gas_price,
          endowment: tx.value,
          init_code: tx.init,
          stack_depth: stack_depth,
          block_header: block_header
        }

        {_, result} = Contract.create(params)
        result
      else
        params = %Contract.MessageCall{
          state: state_0,
          sender: sender,
          originator: originator,
          recipient: tx.to,
          contract: tx.to,
          available_gas: gas,
          gas_price: tx.gas_price,
          value: tx.value,
          apparent_value: apparent_value,
          data: tx.data,
          stack_depth: stack_depth,
          block_header: block_header
        }

        # Note, we only want to take the first 3 items from the tuples,
        # as designated Θ_3 in the literature Θ_3
        {state, remaining_gas_, sub_state_, _output} = Contract.message_call(params)

        {state, remaining_gas_, sub_state_}
      end

    refund = MathHelper.calculate_total_refund(tx, remaining_gas, sub_state.refund)

    state_after_gas = finalize_transaction_gas(state_p, sender, tx, refund, block_header)

    state_after_selfdestruct =
      Enum.reduce(sub_state.selfdestruct_list, state_after_gas, fn address, state ->
        Account.del_account(state, address)
      end)

    expended_gas = tx.gas_limit - refund

    # { σ', Υ^g, Υ^l }, as defined in Eq.(79) and Eq.(80)
    {state_after_selfdestruct, expended_gas, sub_state.logs}
  end

  @doc """
  Performs first step of transaction, which adjusts the sender's
  balance and nonce, as defined in Eq.(67), Eq.(68) and Eq.(69)
  of the Yellow Paper.

  Note: we pass in sender here so we do not need to compute it
        several times (since we'll use it elsewhere).

  TODO: we execute this as two separate updates; we may want to
        combine a series of updates before we update our state.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 1000, nonce: 7})
      iex> state = Blockchain.Transaction.begin_transaction(state, <<0x01::160>>, %Blockchain.Transaction{gas_price: 3, gas_limit: 100})
      iex> Blockchain.Account.get_account(state, <<0x01::160>>)
      %Blockchain.Account{balance: 700, nonce: 8}
  """
  @spec begin_transaction(EVM.state(), EVM.address(), t) :: EVM.state()
  def begin_transaction(state, sender, trx) do
    state
    |> Account.dec_wei(sender, trx.gas_limit * trx.gas_price)
    |> Account.increment_nonce(sender)
  end

  @doc """
  Finalizes the gas payout, repaying the sender for excess or refunded gas
  and paying the miner his due. This is defined according to Eq.(73), Eq.(74),
  Eq.(75) and Eq.(76) of the Yellow Paper.

  Again, we take a sender so that we don't have to re-compute the sender
  address several times.

  ## Examples

      iex> trx = %Blockchain.Transaction{gas_price: 10, gas_limit: 30}
      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 11})
      ...>   |> Blockchain.Account.put_account(<<0x02::160>>, %Blockchain.Account{balance: 22})
      iex> Blockchain.Transaction.finalize_transaction_gas(state, <<0x01::160>>, trx, 5, %Block.Header{beneficiary: <<0x02::160>>})
      ...>   |> Blockchain.Account.get_accounts([<<0x01::160>>, <<0x02::160>>])
      [
        %Blockchain.Account{balance: 61},
        %Blockchain.Account{balance: 272},
      ]
  """
  @spec finalize_transaction_gas(EVM.state(), EVM.address(), t, Gas.t(), Block.Header.t()) ::
          EVM.state()
  def finalize_transaction_gas(state, sender, trx, total_refund, block_header) do
    # Eq.(74)
    # Eq.(75)
    state
    |> Account.add_wei(sender, total_refund * trx.gas_price)
    |> Account.add_wei(block_header.beneficiary, (trx.gas_limit - total_refund) * trx.gas_price)
  end

  @doc """
  Defines the "intrinsic gas cost," that is the amount of gas
  this transaction requires to be paid prior to execution. This
  is defined as g_0 in Eq.(54), Eq.(55) and Eq.(56) of the
  Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<1::160>>, init: <<>>, data: <<1, 2, 0, 3>>}, %Block.Header{number: 5})
      3 * 68 + 4 + 21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<1::160>>, init: <<>>, data: <<1, 2, 0, 3>>}, %Block.Header{number: 5_000_000})
      3 * 68 + 4 + 21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<1::160>>, init: <<>>, data: <<>>}, %Block.Header{number: 5_000_000})
      21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<>>, init: <<1, 2, 0, 3>>, data: <<>>}, %Block.Header{number: 5})
      3 * 68 + 4 + 21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<>>, init: <<1, 2, 0, 3>>, data: <<>>}, %Block.Header{number: 5_000_000})
      3 * 68 + 4  + 21000
  """
  @spec intrinsic_gas_cost(t, Header.t()) :: Gas.t()
  def intrinsic_gas_cost(tx, block_header) do
    data_cost = input_data_cost(tx)
    cc_cost = contract_creation_cost(tx, block_header)
    data_cost + cc_cost + Gas.g_transaction()
  end

  defp input_data_cost(tx) do
    tx
    |> input_data()
    |> Gas.g_txdata()
  end

  defp contract_creation_cost(_tx, _block_header) do
    # TODO: https://github.com/poanetwork/mana/issues/190
    #
    # cost of tx’s associated data and initialisation EVM-code,
    # depending on whether the transaction is for contract-creation or message-call
    #
    # if tx.to == <<>> and Header.is_after_homestead?(block_header),
    # do: Gas.g_txcreate(),
    # else: 0
    0
  end

  def contract_creation?(%Blockchain.Transaction{to: <<>>}), do: true
  def contract_creation?(%Blockchain.Transaction{to: _recipient}), do: false
end
