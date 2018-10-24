defmodule EVM.Configuration.SpuriousDragon do
  alias EVM.Configuration.TangerineWhistle

  use EVM.Configuration,
    fallback_config: TangerineWhistle,
    overrides: %{
      exp_byte_cost: 50,
      code_size_limit: 24_577,
      increment_nonce_on_create: true,
      empty_account_value_transfer: true,
      clean_touched_accounts: true
    }

  @impl true
  def selfdestruct_cost(config, params) do
    TangerineWhistle.selfdestruct_cost(config, params)
  end

  @impl true
  def limit_contract_code_size?(config, size), do: size >= config.code_size_limit
end
