# 0.1.13
* Update gas calculations for CALL and RETURN opcodes
# 0.1.12
* Move state management out of the EVM and use `AccountInterface` instead
# 0.1.11
* Add basic implementation of the CALL opcode
# 0.1.10
* Update interfaces to match `Blockchain` downstream
* Add `Block.Header.hash/1` function
# 0.1.9
* Subtract gas before running operations
* Move program counter logic to its own module
* Refactor memory gas cost calculations
# 0.1.8
* Update gas cost calculations
* Move process counter manipulation into the opcode implementations
* Fixed `BLOCKHASH` opcode
# 0.1.7
* Add in a full debugger
# 0.1.6
* Add in parameters that could be tweaked by different chains (e.g. `min_gas_limit` in Ropsten)
* Add Bitwise logic opcodes and SHA3
# 0.1.5
* Add `CREATE`, `CALL`, `CALLCODE` and `DELEGATECALL` op calls
* Add block information opcodes
# 0.1.4
* Large refactor / cleanup of how opcodes are run / organized.
* Added significant number of mathematic opcodes.
* Added common test suite for verify result of opcodes.
* Fixed gas calculation for a number of opcodes.
# 0.1.3
* Expand allowed trie definition from EVM.
# 0.1.2
* Fix typespec to allow nil return from `EVM.VM.run/3`.
# 0.1.1
* Fix all typespec issues and get dialyzer returning straight greens.
