defmodule ExWire.Packet.CapabilityTest do
  use ExUnit.Case, async: true
  doctest ExWire.Packet.Capability

  describe "new/1" do
    test "String name" do
      capability = ExWire.Packet.Capability.new({"test", 123})

      assert capability == %ExWire.Packet.Capability{
               name: "test",
               version: 123
             }
    end
  end

  describe "get_matching_capabilities/2" do
    test "Empty list, empty map" do
      matching_capabilities = ExWire.Packet.Capability.get_matching_capabilities([], %{})
      assert matching_capabilities == []
    end

    test "Populated list, empty map" do
      capability = ExWire.Packet.Capability.new({"test", 123})

      matching_capabilities =
        ExWire.Packet.Capability.get_matching_capabilities([capability], %{})

      assert matching_capabilities == []
    end

    test "Empty list, populated map" do
      map = %{eth: ExWire.Packet.Capability.Eth}
      matching_capabilities = ExWire.Packet.Capability.get_matching_capabilities([], map)
      assert matching_capabilities == []
    end

    test "Populated list, populated map, no matches" do
      capability = ExWire.Packet.Capability.new({"test", 123})
      map = %{eth: ExWire.Packet.Capability.Eth}

      matching_capabilities =
        ExWire.Packet.Capability.get_matching_capabilities([capability], map)

      assert matching_capabilities == []
    end

    test "Populated list, populated map, one match" do
      name = ExWire.Packet.Capability.Eth.get_name()
      version = List.first(ExWire.Packet.Capability.Eth.get_supported_versions())
      map = %{name => ExWire.Packet.Capability.Eth}

      matched_capability = ExWire.Packet.Capability.new({name, version})

      capabilities = [
        ExWire.Packet.Capability.new({"test", 123}),
        matched_capability
      ]

      matching_capabilities =
        ExWire.Packet.Capability.get_matching_capabilities(capabilities, map)

      assert matching_capabilities == [matched_capability]
    end

    test "Multiple Eth Versions" do
      name = ExWire.Packet.Capability.Eth.get_name()
      map = %{name => ExWire.Packet.Capability.Eth}
      supported_versions = ExWire.Packet.Capability.Eth.get_supported_versions()
      expected_version = Enum.max(supported_versions)

      capabilities =
        for version <- supported_versions, do: ExWire.Packet.Capability.new({name, version})

      matching_capabilities =
        ExWire.Packet.Capability.get_matching_capabilities(capabilities, map)

      expected_match = ExWire.Packet.Capability.new({name, expected_version})

      assert matching_capabilities == [expected_match]
    end

    test "Eth and Par" do
      map = %{
        ExWire.Packet.Capability.Eth.get_name() => ExWire.Packet.Capability.Eth,
        ExWire.Packet.Capability.Par.get_name() => ExWire.Packet.Capability.Par
      }

      supported_eth_versions = ExWire.Packet.Capability.Eth.get_supported_versions()
      expected_eth_version = Enum.max(supported_eth_versions)

      supported_par_versions = ExWire.Packet.Capability.Par.get_supported_versions()
      expected_par_version = Enum.max(supported_par_versions)

      eth_capabilities =
        for version <- supported_eth_versions,
            do: ExWire.Packet.Capability.new({ExWire.Packet.Capability.Eth.get_name(), version})

      par_capabilities =
        for version <- supported_par_versions,
            do: ExWire.Packet.Capability.new({ExWire.Packet.Capability.Par.get_name(), version})

      matching_capabilities =
        ExWire.Packet.Capability.get_matching_capabilities(
          eth_capabilities ++ par_capabilities,
          map
        )

      expected_eth_match =
        ExWire.Packet.Capability.new(
          {ExWire.Packet.Capability.Eth.get_name(), expected_eth_version}
        )

      expected_par_match =
        ExWire.Packet.Capability.new(
          {ExWire.Packet.Capability.Par.get_name(), expected_par_version}
        )

      assert MapSet.new(matching_capabilities) ==
               MapSet.new([expected_eth_match, expected_par_match])
    end
  end

  describe "get_packets_for_capability/2" do
    test "Test unsupported, empty map" do
      capability = ExWire.Packet.Capability.new({"test", 123})
      result = ExWire.Packet.Capability.get_packets_for_capability(capability, %{})

      assert result == :unsupported_capability
    end

    test "Test Supported" do
      name = ExWire.Packet.Capability.Eth.get_name()
      version = List.first(ExWire.Packet.Capability.Eth.get_supported_versions())
      map = %{name => ExWire.Packet.Capability.Eth}
      matched_capability = ExWire.Packet.Capability.new({name, version})

      result = ExWire.Packet.Capability.get_packets_for_capability(matched_capability, map)

      assert is_list(result)
      assert length(result) > 0
    end
  end

  describe "are_we_capable/2" do
    test "Empty map, not capable" do
      capability = ExWire.Packet.Capability.new({"test", 123})
      result = ExWire.Packet.Capability.are_we_capable?(capability, %{})

      assert result == false
    end

    test "No match, not capable" do
      capability = ExWire.Packet.Capability.new({"test", 123})
      name = ExWire.Packet.Capability.Eth.get_name()
      map = %{name => ExWire.Packet.Capability.Eth}

      result = ExWire.Packet.Capability.are_we_capable?(capability, map)

      assert result == false
    end

    test "Match => capable" do
      name = ExWire.Packet.Capability.Eth.get_name()
      map = %{name => ExWire.Packet.Capability.Eth}
      version = List.first(ExWire.Packet.Capability.Eth.get_supported_versions())
      capability = ExWire.Packet.Capability.new({name, version})

      result = ExWire.Packet.Capability.are_we_capable?(capability, map)

      assert result == true
    end
  end
end
