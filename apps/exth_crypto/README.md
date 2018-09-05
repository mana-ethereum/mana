# ExthCrypto

ExthCrypto handles the majority of cryptographic operations for Mana-Ethereum. The goal of this project is to give each project a common set of cryptographic functions where the backend can be swapped as needed. Additionally, more complicated protocols (such as ECIES) can be implemented and tested in this project.

Note: we opt, whenever possible, to use erlang core or open-source implementations for all functions. The goal of this project is to create a consistent API for cryptographic functions that can be referenced from Mana-Ethereum projects. The goal of this project is not to re-write such functions in native erlang or Elixir.

We currently support:

 * AES symmetric encryption in block mode and (simplified) stream mode
 * Elliptic Curve Diffie Hellman (ECDH) key exchange
 * ECIES perfect-forward secret generation
 * SHA1, SHA2 and Keccak one-way cryptographic hash functions
 * NIST-SP-800-56 key derivation function
 * HMAC with SHA1, SHA2 or Keccak
 * Elliptic Curve Digital Signature Algorithm (ECDSA) with public key recovery

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exth_crypto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:exth_crypto, "~> 0.1.4"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exth_crypto](https://hexdocs.pm/exth_crypto).

