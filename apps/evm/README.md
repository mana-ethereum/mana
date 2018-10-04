# EVM

The EVM is a fully working Ethereum Virtual Machine which follows _Section 9: Execution Model_ of the [Yellow Paper](https://github.com/ethereum/yellowpaper). The EVM handles all transaction processing (messages sent between accounts) and serves as a runtime environment for smart contracts. For more information on our Elixir implementation, please see [Ethereum Virtual Machine in Elixir](https://www.badykov.com/elixir/2018/04/29/evm-basics/).

## Data Structures

As discussed in the paper, we define several data structures.

* `State:` The world state of Ethereum, defined as the root hash of a Merkle Patricia Trie containing all account data. See Section 4.1 of the Yellow Paper, or the [merkle_patricia_tree](../merkle_patricia_tree) umbrella project in this repo.
* `Machine State:` This structure effectively encodes the current context of a running VM. The Machine State is used during execution of the program and discarded on completion. Before we finish, we extract the gas used and return the value from this object. The machine state includes:
  * the program counter
  * memory contents
  * active number of words in memory
  * the stack contents
* `Sub State:` The sub state tracks the selfdestruct list (contracts to destroy), the log, and the refund (for cleaning up storage) for a contract execution.
* `Execution Environment:` This tracks information about the call into a contract, such as the machine code itself and the value passed to the contract or message call. Other than stack depth, this is generally not mutated during execution of the machine.

### File Structure Notes
- All operations as defined in the yellow paper are located in the [lib/evm/operation](lib/evm/operation) folder.
- [liv/evm/vm.ex](lib/evm/vm.ex) contains the following virtual machine functions from the yellow paper:
  - `EVM.VM.run/2`: Ξ function.
  - `EVM.VM.exec/3`: X function.
  - `EVM.VM.cycle/3`: O function.
  - `EVM.Functions.is_exception_halt?/2`: Z function.


## Installation

Installation is handled through the bin/setup procedure in the [Mana-Ethereum README](../../README.md).

## Example

The following example is from [Ethereum Virtual Machine in Elixir](https://www.badykov.com/elixir/2018/04/29/evm-basics/). It illustrates the `VMTests/vmArithmeticTest/add3.json` test from the [Ethereum common test protocol](https://github.com/ethereum/tests/).

### Example Setup

1. Follow the installation procedure in the [Mana-Ethereum README](../../README.md).

2. Add the input/output code to print debugging information.
   - Go to `lib/evm/vm.ex`.

   - Find the `cycle/3` method and **add the logger code** before the return value
      ```elixir
      def cycle(machine_state, sub_state, exec_env) do
      operation = MachineCode.current_operation(machine_state, exec_env)
      inputs = Operation.inputs(operation, machine_state)

      # more code

      final_machine_state
      |> EVM.Logger.log_stack()
      |> EVM.Logger.log_state(operation)

      {final_machine_state, n_sub_state, n_exec_env}
      ```
   - Save the file.

 4. Start the Elixir REPL.  `cd apps/evm && iex -S mix`

### Create an Execution Environment for Testing.

Copy in the following code to create a mock environment with the fields required to process a transaction.

```
iex> env = %EVM.ExecEnv{
  account_interface: %EVM.Interface.Mock.MockAccountInterface{
    account_map: %{},
    contract_result: %{gas: nil, output: nil, sub_state: nil}
  },
  address: 87579061662017136990230301793909925042452127430,
  block_header_info: %EVM.Mock.MockBlockHeaderInfo{
    block_header: nil,
    block_map: %{}
  },
  data: "",
  gas_price: <<90, 243, 16, 122, 64, 0>>,
  machine_code: <<96, 1, 96, 1, 1, 96, 1, 85>>,
  originator: <<205, 23, 34, 242, 148, 125, 239, 76, 241, 68, 103, 157, 163,
    156, 76, 50, 189, 195, 86, 129>>,
  sender: 1170859069521887415590932569929099639409724315265,
  stack_depth: 0,
  value_in_wei: <<13, 224, 182, 179, 167, 100, 0, 0>>
}
```

For this test, we are only interested in the `machine_code` field. It is represented as a binary.

### Decompile the Code to View the Machine Operations

`iex> env.machine_code |> EVM.MachineCode.decompile`

You should see the following decompiled instructions:

`[:push1, 1, :push1, 1, :add, :push1, 1, :sstore]`

As you can see, the machine code:
1. places two 1's on the stack
2. adds them
3. places another 1 on the stack
4. stores the second stack item to storage. The storage index is the first stack item.

### Run the Machine Code

`iex>  EVM.VM.run(1000000, env)`

You should see the following operations:

```
stack:
[]
operation: push1
stack:
[1]
operation: push1
stack:
[1, 1]
operation: add
stack:
[2]
operation: push1
stack:
[1, 2]
operation: sstore
stack:
[]
```

Within the execution environment, you will see the new storage value: `storage: %{1 => 2}`.

```
{..., %EVM.SubState{logs: [], refund: 0, suicide_list: []},
 %EVM.ExecEnv{
   account_interface: %EVM.Interface.Mock.MockAccountInterface{
     account_map: %{
       87579061662017136990230301793909925042452127430 => %{
         balance: 0,
         nonce: 0,
         storage: %{1 => 2}
       }
     },
     contract_result: %{gas: nil, output: nil, sub_state: nil}
   },
   address: 87579061662017136990230301793909925042452127430,
   block_header_info: %EVM.Mock.MockBlockHeaderInfo{
     block_header: nil,
     block_map: %{}
   },
   data: "",
   gas_price: <<90, 243, 16, 122, 64, 0>>,
   machine_code: <<96, 0, 96, 0, 1, 96, 0, 85>>,
   originator: <<205, 23, 34, 242, 148, 125, 239, 76, 241, 68, 103, 157, 163,
     156, 76, 50, 189, 195, 86, 129>>,
   sender: 1170859069521887415590932569929099639409724315265,
   stack_depth: 0,
   value_in_wei: <<13, 224, 182, 179, 167, 100, 0, 0>>
 }, ""}
```

## Contributing

See the [CONTRIBUTING](../../CONTRIBUTING.md) document for contribution, testing and pull request protocol.
