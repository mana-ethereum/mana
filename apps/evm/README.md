# EVM

The EVM is a fully working Ethereum Virtual Machine. This machine effective encodes Section 9 "Execution Model" of the [Yellow Paper](http://gavwood.com/Paper.pdf).

# Basics

As discussed in the paper, we define a few data structures.

* State - The world state of Ethereum, defined as the root hash of a Merkle Patricia Trie containing all account data. See Section 4.1 of the Yellow Paper, or explore the [merkle_patricia_trie](https://github.com/hayesgm/exthereum/tree/master/apps/merkle_patricia_trie) umbrella project in this repo.
* The Machine State - This structure effectively encodes the current context of a running VM (e.g. the program counter, the current memory data, etc). This structure is simply used during execution of the program, and thrown away after it completes. Before we finish, we extract the gas used and return value from this object.
* The Sub State - The sub state tracks the suicide list (contracts to destroy), the logs and the refund (for cleaning up storage) for a contract execution.
* The Execution Environment - This tracks information about the call into a contract, such as the machine code itself and the value passed to the contract or message call. Other than stack depth, this is generally not mutated during execution of the machine.

# Examples

Here is an example of a simple program running on the VM:

```elixir
EVM.VM.run(%{}, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])})
{%{}, 5, [], [], 0, <<0x08::256>>}
```

Let's walk through this step-by-step. First, we take some pseudo-machine code and compile it. Thus, the machine code above becomes `<<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>` before it's passed to the virtual machine. The code itself says to push two values (hard-coded) on to the stack (3 and 5). Then we ask the machine to take the top two values off of the stack, add them, and place them back on to the stack. This leaves the stack as [8]. Then we ask the machine to push zero on to the stack and run store. This stores the value "8" at memory offset 0. Finally, we push two more values 0 and 32 to tell the machine that we'll be returning the first 32 bytes of memory as our return result (since we count words and gas in blocks of 32, we might as well return the full value). We then return and get the correct result of `<<0x08::256>>` as a erlang binary.

TODO: Add diagram or debug output