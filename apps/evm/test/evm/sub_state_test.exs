defmodule EVM.SubStateTest do
  use ExUnit.Case, async: true
  doctest EVM.SubState

  describe "add_log/4" do
    test "adds logs to the end" do
      sub_state = %EVM.SubState{
        logs: [
          %EVM.LogEntry{
            address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
            data: "adsfa",
            topics: [1, 10, 12]
          }
        ],
        refund: 0,
        selfdestruct_list: []
      }

      new_substate = EVM.SubState.add_log(sub_state, 1, [5], "zxcz")

      expected_last_log_entry = %EVM.LogEntry{
        address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>,
        data: "zxcz",
        topics: [
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 5>>
        ]
      }

      assert expected_last_log_entry == List.last(new_substate.logs)
    end
  end
end
