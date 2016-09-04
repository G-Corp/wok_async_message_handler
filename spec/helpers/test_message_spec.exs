defmodule WokAsyncMessageHandler.Helpers.TestMessageSpec do 
  use ESpec

  describe "#build_event_message" do

    let :expected_message, do: {
      :message_transfert, :undefined, {
        :wok_msg, {
          :message, 
          "6a79129d-0990-46cb-9b89-893c48bf2173", 
          "to_bot",
          "from_bot", 
          %{}, 
          %{message_id: 23}, 
          "[{\"version\":1,\"payload\":{\"name\":\"bob\",\"age\":69}}]"
        }, 
        {:wok_msg_resp, false, :undefined, :undefined, :undefined, "" }, 
        :undefined, :undefined, :undefined
      }, 
      1, 
      "bots_events", 
      :undefined, 
      :undefined, 
      :undefined, 
      :undefined, 
      :undefined, 
      :undefined
    } 

    let :payload, do: %{"name" => "bob", "age" => 69}
    let :from, do: "from_bot"

    before do: allow(Ecto.UUID).to accept(:generate, fn() -> "6a79129d-0990-46cb-9b89-893c48bf2173" end)

    it do: expect(described_module.build_event_message(payload, from, 23)).to eq(expected_message)
  end
end
