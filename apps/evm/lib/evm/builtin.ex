defmodule EVM.Builtin do
  @moduledoc """
  Implements the built-in functions as defined in Appendix E
  of the Yellow Paper. These are contract functions that
  natively exist in Ethereum.
  """

  @doc """
  A precompiled contract that recovers a public key from a signed hash
  (Elliptic curve digital signature algorithm public key recovery function)
  """

  @spec run_ecrec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_ecrec(gas, exec_env) do
    EVM.Builtin.Ecrec.exec(gas, exec_env)
  end

  @doc """
  Runs SHA256 hashing
  """
  @spec run_sha256(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_sha256(gas, exec_env) do
    EVM.Builtin.Sha256.exec(gas, exec_env)
  end

  @doc """
  Runs RIPEMD160 hashing
  """
  @spec run_rip160(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_rip160(gas, exec_env) do
    EVM.Builtin.Rip160.exec(gas, exec_env)
  end

  @doc """
  Identity simply returnes the output as the input
  """
  @spec run_id(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_id(gas, exec_env) do
    EVM.Builtin.ID.exec(gas, exec_env)
  end

  @doc """
  Arbitrary-precision exponentiation under modulo
  """
  @spec mod_exp(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def mod_exp(gas, exec_env) do
    EVM.Builtin.ModExp.exec(gas, exec_env)
  end

  @doc """
  Elliptic curve addition
  """
  @spec ec_add(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def ec_add(gas, exec_env) do
    EVM.Builtin.EcAdd.exec(gas, exec_env)
  end

  @doc """
  Elliptic curve multiplication
  """
  @spec ec_mult(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def ec_mult(gas, exec_env) do
    EVM.Builtin.EcMult.exec(gas, exec_env)
  end

  @doc """
  Elliptic curve pairing
  """
  @spec ec_pairing(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def ec_pairing(gas, exec_env) do
    EVM.Builtin.EcPairing.exec(gas, exec_env)
  end
end
