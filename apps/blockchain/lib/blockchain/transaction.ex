defmodule Blockchain.Transaction do
  @moduledoc """
  This module encodes the transaction object,
  defined in Section 4.2 of the Yellow Paper.
  We are focused on implementing 𝛶, as defined in Eq.(1).
  """

  require Logger

  alias EthCore.Block.Header
  alias Blockchain.{Account, Contract, MathHelper}
  alias Blockchain.Transaction.{Signature, Validation}
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
          v: Signature.hash_v(),
          r: Signature.hash_r(),
          s: Signature.hash_s(),
          init: EVM.MachineCode.t(),
          data: binary()
        }

  @doc """
  Encodes a transaction such that it can be RLP-encoded.
  This is defined at L_T Eq.(15) in the Yellow Paper.
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(tx, include_vrs \\ true) do
    base = [
      tx.nonce |> BitHelper.encode_unsigned(),
      tx.gas_price |> BitHelper.encode_unsigned(),
      tx.gas_limit |> BitHelper.encode_unsigned(),
      tx.to,
      tx.value |> BitHelper.encode_unsigned(),
      if(tx.to == <<>>, do: tx.init, else: tx.data)
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
  Decodes a transaction that was previously encoded
  using `Transaction.serialize/1`. Note, this is the
  inverse of L_T Eq.(15) defined in the Yellow Paper.
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
  Performs transaction execution, as defined in Section 6
  of the Yellow Paper, defined as Eq.(1) and Eq.(59),
  Eq.(70), Eq.(79) and Eq.(80).

  From the Yellow Paper, T_o is the original transactor, which can differ from the
  sender in the case of a message call or contract creation
  not directly triggered by a transaction but coming from
  the execution of EVM-code.
  """
  @spec execute(EVM.state(), t, Header.t()) :: {EVM.state(), Gas.t(), EVM.SubState.logs()}
  def execute(state, tx, header) do
    case Validation.validate(state, tx, header) do
      :valid ->
        do_execute(state, tx, header)

      {:invalid, error} ->
        Logger.debug("Invalid transaction: #{error}")
       {state, 0, []}
    end
  end

  defp do_execute(state, tx, header) do
    {:ok, sender} = Signature.sender(tx)

    state_0 = begin_transaction(state, sender, tx)

    # sender and originator are the same for transaction execution
    originator = sender
    # stack depth starts at zero for transaction execution
    stack_depth = 0
    # apparent value is the full value for transaction execution
    apparent_value = tx.value
    # gas is equal to what was just subtracted from sender account less intrinsic gas cost
    gas = tx.gas_limit - intrinsic_gas_cost(tx, header)

    {state_p, remaining_gas, sub_state} =
      case tx.to do
        # Λ
        <<>> ->
          params = %Contract.CreateContract{
            state: state_0,
            sender: sender,
            originator: originator,
            available_gas: gas,
            gas_price: tx.gas_price,
            endowment: tx.value,
            init_code: tx.init,
            stack_depth: stack_depth,
            block_header: header
          }

          Contract.create(params)

        recipient ->
          params = %Contract.MessageCall{
            state: state_0,
            sender: sender,
            originator: originator,
            recipient: recipient,
            contract: recipient,
            available_gas: gas,
            gas_price: tx.gas_price,
            value: tx.value,
            apparent_value: apparent_value,
            data: tx.data,
            stack_depth: stack_depth,
            block_header: header
          }

          # Note, we only want to take the first 3 items from the tuples,
          # as designated Θ_3 in the literature Θ_3
          {state, remaining_gas_, sub_state_, _output} = Contract.message_call(params)

          {state, remaining_gas_, sub_state_}
      end

    refund = MathHelper.calculate_total_refund(tx, remaining_gas, sub_state.refund)

    state_after_gas = finalize_transaction_gas(state_p, sender, tx, refund, header)

    state_after_selfdestruct =
      Enum.reduce(sub_state.selfdestruct_list, state_after_gas, fn address, state ->
        Account.del_account(state, address)
      end)

    expended_gas = tx.gas_limit - remaining_gas

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
      iex> Blockchain.Transaction.finalize_transaction_gas(state, <<0x01::160>>, trx, 5, %EthCore.Block.Header{beneficiary: <<0x02::160>>})
      ...>   |> Blockchain.Account.get_accounts([<<0x01::160>>, <<0x02::160>>])
      [
        %Blockchain.Account{balance: 61},
        %Blockchain.Account{balance: 272},
      ]
  """
  @spec finalize_transaction_gas(EVM.state(), EVM.address(), t, Gas.t(), Header.t()) ::
          EVM.state()
  def finalize_transaction_gas(state, sender, trx, total_refund, header) do
    # Eq.(74)
    # Eq.(75)
    state
    |> Account.add_wei(sender, total_refund * trx.gas_price)
    |> Account.add_wei(header.beneficiary, (trx.gas_limit - total_refund) * trx.gas_price)
  end

  @doc """
  Defines the "intrinsic gas cost," that is the amount of gas
  this transaction requires to be paid prior to execution. This
  is defined as g_0 in Eq.(54), Eq.(55) and Eq.(56) of the
  Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<1::160>>, init: <<>>, data: <<1, 2, 0, 3>>}, %EthCore.Block.Header{number: 5})
      3 * 68 + 4 + 21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<1::160>>, init: <<>>, data: <<1, 2, 0, 3>>}, %EthCore.Block.Header{number: 5_000_000})
      3 * 68 + 4 + 21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<1::160>>, init: <<>>, data: <<>>}, %EthCore.Block.Header{number: 5_000_000})
      21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<>>, init: <<1, 2, 0, 3>>, data: <<>>}, %EthCore.Block.Header{number: 5})
      3 * 68 + 4 + 21000

      iex> Blockchain.Transaction.intrinsic_gas_cost(%Blockchain.Transaction{to: <<>>, init: <<1, 2, 0, 3>>, data: <<>>}, %EthCore.Block.Header{number: 5_000_000})
      3 * 68 + 4 + 32000 + 21000
  """
  @spec intrinsic_gas_cost(t, Header.t()) :: Gas.t()
  def intrinsic_gas_cost(tx, header) do
    # cost of tx’s associated data and initialisation EVM-code,
    # depending on whether the transaction is for contract-creation or message-call
    data_cost = Gas.g_txdata(tx.init) + Gas.g_txdata(tx.data)
    cc_cost = contract_creation_cost(tx, header)
    data_cost + cc_cost + Gas.g_transaction()
  end

  defp contract_creation_cost(tx, header) do
    if tx.to == <<>> and header.number >= Header.homestead(),
      do: Gas.g_txcreate(),
      else: 0
  end
end
