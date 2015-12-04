defmodule NVim.LinkTest do
  use ExUnit.Case
  alias NVim.Link

  test "unpack messages with long string" do
    message_pack_with_long_string = <<148, 0, 2, 164, 112, 111, 108, 108, 145, 145, 217, 32,
    97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97,
    97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97, 97>>

    {_, parsed_message} = NVim.Link.parse_msgs(message_pack_with_long_string, [])

    assert parsed_message == [[0, 2, "poll", [["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]]]]
  end
end
