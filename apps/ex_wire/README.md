# ExWire

Elixir Client for RLPx, DevP2P and Eth Wire Protocol.

## Usage

For the time being, this can be used to sync the block chain from a given network (currently defaulted to Ropsten).

You can run `iex -S mix` and you should see:

```
12:59:23.818 [debug] [Network] [6ce059...1acd9d] Established outbound connection with 13.84.180.240, sending auth.

12:59:23.858 [debug] [Network] Sending EIP8 Handshake to 13.84.180.240

12:59:23.884 [debug] [Network] [6ce059...1acd9d] Sending raw data message of length 388 byte(s) to 13.84.180.240

12:59:23.886 [debug] [Sync] Requesting block 0

...

12:59:24.496 [debug] [Packet] Peer sent 1 header(s)

12:59:24.540 [debug] [Block Queue] Verified block and added to new block tree

12:59:24.540 [debug] [Sync] Requesting block 1

12:59:24.541 [info]  [Network] [6ce059...1acd9d] Sending packet Elixir.ExWire.Packet.GetBlockHeaders to 13.84.180.240

12:59:24.593 [debug] [Network] [6ce059...1acd9d] Got packet Elixir.ExWire.Packet.BlockHeaders from 13.84.180.240

12:59:24.593 [debug] [Packet] Peer sent 1 header(s)

12:59:24.595 [debug] [Block Queue] Verified block and added to new block tree
```

In the future, we will continue to grow and built out a proper syncing ability. It's likely the proper interface (with CLI tools) will not be this module directly, but instead a general CLI which calls into this module.
