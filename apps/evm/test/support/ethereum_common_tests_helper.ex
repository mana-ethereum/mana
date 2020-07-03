defmodule EVM.EthereumCommonTestsHelper do
  @ethereum_common_tests_path File.cwd!() <> "/../../ethereum_common_tests/"

  def common_tests_path do
    @ethereum_common_tests_path
  end

  def basic_tests_path do
    common_tests_path() <> "/BasicTests"
  end
end
