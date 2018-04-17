defmodule Blockchain.Transaction do
  @moduledoc """
  This module encodes the transaction object, defined in Section 4.3
  of the Yellow Paper (http://gavwood.com/Paper.pdf). We are focused
  on implementing 𝛶, as defined in Eq.(1).
  """

  alias Blockchain.Account
  alias Block.Header

  defstruct [
    nonce: 0,         # Tn
    gas_price: 0,     # Tp
    gas_limit: 0,     # Tg
    to: <<>>,         # Tt
    value: 0,         # Tv
    v: nil,           # Tw
    r: nil,           # Tr
    s: nil,           # Ts
    init: <<>>,       # Ti
    data: <<>>,       # Td
  ]

  @type t :: %__MODULE__{
    nonce: EVM.val,
    gas_price: EVM.val,
    gas_limit: EVM.val,
    to: EVM.address | <<_::0>>,
    value: EVM.val,
    v: Blockchain.Transaction.Signature.hash_v,
    r: Blockchain.Transaction.Signature.hash_r,
    s: Blockchain.Transaction.Signature.hash_s,
    init: EVM.MachineCode.t,
    data: binary(),
  }

  @doc """
  Encodes a transaction such that it can be RLP-encoded.
  This is defined at L_T Eq.(14) in the Yellow Paper.

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
  @spec serialize(t) :: ExRLP.t
  def serialize(trx, include_vrs \\ true) do
    base = [
      trx.nonce |> BitHelper.encode_unsigned,
      trx.gas_price |> BitHelper.encode_unsigned,
      trx.gas_limit |> BitHelper.encode_unsigned,
      trx.to,
      trx.value |> BitHelper.encode_unsigned,
      (if trx.to == <<>>, do: trx.init, else: trx.data),
    ]

    if include_vrs do
      base ++ [
        trx.v |> BitHelper.encode_unsigned,
        trx.r |> BitHelper.encode_unsigned,
        trx.s |> BitHelper.encode_unsigned
      ]
    else
      base
    end
  end

  @doc """
  Decodes a transaction that was previously encoded
  using `Transaction.serialize/1`. Note, this is the
  inverse of L_T Eq.(14) defined in the Yellow Paper.

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
  @spec deserialize(ExRLP.t) :: t
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
      s: :binary.decode_unsigned(s),
    }
  end

  @doc """
  Validates the validity of a transaction that is required to be
  true before we're willing to execute a transaction. This is
  specified in Section 6.2 of the Yellow Paper Eq.(65) and Eq.(66).

  TODO: Consider returning a set of reasons, instead of a singular reason.

  ## Examples

      # Sender address is nil
      iex> trx = %Blockchain.Transaction{data: <<>>, gas_limit: 1_000, gas_price: 1, init: <<1>>, nonce: 5, to: <<>>, value: 5, r: 1, s: 2, v: 3}
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{})
      {:invalid, :invalid_sender}

      # Sender account is nil
      iex> private_key = <<1::256>>
      iex> trx =
      ...>   %Blockchain.Transaction{data: <<>>, gas_limit: 1_000, gas_price: 1, init: <<1>>, nonce: 5, to: <<>>, value: 5}
      ...>   |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{})
      {:invalid, :missing_account}

      # Has sender account, but nonce mismatch
      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> trx =
      ...>   %Blockchain.Transaction{data: <<>>, gas_limit: 1_000, gas_price: 1, init: <<1>>, nonce: 4, to: <<>>, value: 5}
      ...>   |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 1000, nonce: 5})
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{})
      {:invalid, :nonce_mismatch}

      # Insufficient starting gas
      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> trx =
      ...>   %Blockchain.Transaction{data: <<>>, gas_limit: 1_000, gas_price: 1, init: <<1>>, nonce: 5, to: <<>>, value: 5}
      ...>   |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 1000, nonce: 5})
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{})
      {:invalid, :insufficient_intrinsic_gas}

      # Insufficient endowment
      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> trx =
      ...>   %Blockchain.Transaction{data: <<>>, gas_limit: 100_000, gas_price: 1, init: <<1>>, nonce: 5, to: <<>>, value: 5}
      ...>   |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 1000, nonce: 5})
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{})
      {:invalid, :insufficient_balance}

      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> trx =
      ...>   %Blockchain.Transaction{data: <<>>, gas_limit: 100_000, gas_price: 1, init: <<1>>, nonce: 5, to: <<>>, value: 5}
      ...>   |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 100_001, nonce: 5})
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{})
      {:invalid, :insufficient_balance}

      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> trx =
      ...>   %Blockchain.Transaction{data: <<>>, gas_limit: 100_000, gas_price: 1, init: <<1>>, nonce: 5, to: <<>>, value: 5}
      ...>   |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 100_006, nonce: 5})
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{gas_limit: 50_000, gas_used: 49_999})
      {:invalid, :over_gas_limit}

      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> trx =
      ...>   %Blockchain.Transaction{data: <<>>, gas_limit: 100_000, gas_price: 1, init: <<1>>, nonce: 5, to: <<>>, value: 5}
      ...>   |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 100_006, nonce: 5})
      ...> |> Blockchain.Transaction.is_valid?(trx, %Block.Header{gas_limit: 500_000, gas_used: 49_999})
      :valid
  """
  @spec is_valid?(EVM.state, t, Header.t) :: :valid | {:invalid, atom()}
  def is_valid?(state, trx, block_header) do
    g_0 = intrinsic_gas_cost(trx, block_header)
    v_0 = trx.gas_limit * trx.gas_price + trx.value

    case Blockchain.Transaction.Signature.sender(trx) do
      {:error, _reason} -> {:invalid, :invalid_sender}
      {:ok, sender_address} ->
        case Account.get_account(state, sender_address) do
          nil -> {:invalid, :missing_account}
          sender_account ->
            cond do
              sender_account.nonce != trx.nonce -> {:invalid, :nonce_mismatch}
              g_0 > trx.gas_limit -> {:invalid, :insufficient_intrinsic_gas}
              v_0 > sender_account.balance -> {:invalid, :insufficient_balance}
              trx.gas_limit > Header.available_gas(block_header) -> {:invalid, :over_gas_limit}
              true -> :valid
            end
        end
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

  # TODO: Add rich examples in `transaction_test.exs`

  ## Examples

      # Create contract
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 32, :push1, 0, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
      ...>       |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> {state, gas, logs} = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      ...> |> Blockchain.Transaction.execute_transaction(trx, %Block.Header{beneficiary: beneficiary})
      iex> {gas, logs}
      {53780, <<>>}
      iex> Blockchain.Account.get_accounts(state, [sender, beneficiary, contract_address])
      [%Blockchain.Account{balance: 238655, nonce: 6}, %Blockchain.Account{balance: 161340}, %Blockchain.Account{balance: 5, code_hash: <<243, 247, 169, 254, 54, 79, 170, 185, 59, 33, 109, 165, 10, 50, 20, 21, 79, 34, 160, 162, 180, 21, 178, 58, 132, 200, 22, 158, 139, 99, 110, 227>>}]

      # Message call
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: contract_address, value: 5, init: machine_code}
      ...>       |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> {state, gas, logs} = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      ...> |> Blockchain.Account.put_code(contract_address, machine_code)
      ...> |> Blockchain.Transaction.execute_transaction(trx, %Block.Header{beneficiary: beneficiary})
      iex> {gas, logs}
      {21780, <<>>}
      iex> Blockchain.Account.get_accounts(state, [sender, beneficiary, contract_address])
      [%Blockchain.Account{balance: 334655, nonce: 6}, %Blockchain.Account{balance: 65340}, %Blockchain.Account{balance: 5, code_hash: <<216, 114, 80, 103, 17, 50, 164, 75, 162, 123, 123, 99, 162, 105, 226, 15, 215, 200, 136, 216, 29, 106, 193, 119, 1, 173, 138, 37, 219, 39, 23, 231>>}]
  """
  @spec execute_transaction(EVM.state, t, Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.logs }
  def execute_transaction(state, trx, block_header) do
    # TODO: Check transaction validity.
    {:ok, sender} = Blockchain.Transaction.Signature.sender(trx)

    state_0 = begin_transaction(state, sender, trx)

    originator = sender # sender and originator are the same for transaction execution
    stack_depth = 0 # stack depth starts at zero for transaction execution
    apparent_value = trx.value # apparent value is the full value for transaction execution
    gas = trx.gas_limit - intrinsic_gas_cost(trx, block_header) # gas is equal to what was just subtracted from sender account less intrinsic gas cost

    # TODO: Sender versus originator?
    {state_p, remaining_gas, sub_state} = case trx.to do
      <<>> -> Blockchain.Contract.create_contract(state_0, sender, originator, gas, trx.gas_price, trx.value, trx.init, stack_depth, block_header) # Λ
      recipient ->
        # Note, we only want to take the first 3 items from the tuples, as designated Θ_3 in the literature
        {state, remaining_gas_, sub_state_, _output} = Blockchain.Contract.message_call(state_0, sender, originator, recipient, recipient, gas, trx.gas_price, trx.value, apparent_value, trx.data, stack_depth, block_header) # Θ_3

        {state, remaining_gas_, sub_state_}
    end

    refund = calculate_total_refund(trx, remaining_gas, sub_state.refund)

    state_after_gas = finalize_transaction_gas(state_p, sender, trx, refund, block_header)

    state_after_suicides = Enum.reduce(sub_state.suicide_list, state_after_gas, fn (address, state) ->
      Account.del_account(state, address)
    end)

    expended_gas = trx.gas_limit - remaining_gas

    # { σ', Υ^g, Υ^l }, as defined in Eq.(79) and Eq.(80)
    { state_after_suicides, expended_gas, sub_state.logs }
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
  @spec begin_transaction(EVM.state, EVM.address, t) :: EVM.state
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
  @spec finalize_transaction_gas(EVM.state, EVM.address, t, EVM.Gas.t, Block.Header.t) :: EVM.state
  def finalize_transaction_gas(state, sender, trx, total_refund, block_header) do
    state
      |> Account.add_wei(sender, total_refund * trx.gas_price) # Eq.(74)
      |> Account.add_wei(block_header.beneficiary, (trx.gas_limit - total_refund) * trx.gas_price) # Eq.(75)
  end

  @doc """
  Caluclates the amount which should be refunded based on the current transactions
  final usage. This includes the remaining gas plus refunds from clearing storage.

  The specs calls for capping the refund at half of the total amount of gas used.

  This function is defined as `g*` in Eq.(72) in the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 5)
      15

      iex> Blockchain.Transaction.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 99)
      55

      iex> Blockchain.Transaction.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 0)
      10

      iex> Blockchain.Transaction.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 11, 99)
      55
  """
  @spec calculate_total_refund(t, EVM.Gas.t, EVM.SubState.refund) :: EVM.Gas.t
  def calculate_total_refund(trx, remaining_gas, refund) do
    # TODO: Add a math helper, finally
    max_refund = round( :math.floor( ( trx.gas_limit - remaining_gas ) / 2 ) )

    remaining_gas + min(max_refund, refund)
  end

  @doc """
  Defines the "intrinsic gas cost," that is the amount of gas
  this transaction requires to be paid prior to execution. This
  is defined as g_0 in Eq.(62), Eq.(63) and Eq.(64) of the
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
      3 * 68 + 4 + 32000 + 21000
  """
  @spec intrinsic_gas_cost(t, Header.t) :: EVM.Gas.t
  def intrinsic_gas_cost(trx, block_header) do
    EVM.Gas.g_txdata(trx.init) +
    EVM.Gas.g_txdata(trx.data) +
    ( if trx.to == <<>> and Header.is_after_homestead?(block_header), do: EVM.Gas.g_txcreate(), else: 0 ) +
    EVM.Gas.g_transaction()
  end
end
