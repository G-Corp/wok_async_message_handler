defmodule WokAsyncMessageHandler.Helpers.TestMessageSpec do 
  use ESpec

  describe "#build_event_message" do

    let :expected_message, do: {
      :message_transfert, :undefined, {
        :wok_msg, {
          :message, 
          "6a79129d-0990-46cb-9b89-893c48bf2173", 
          "somewhere/inthe/system", 
          "user", %{}, %{message_id: 1}, 
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
    let :to, do: "somewhere/inthe/system"

    before do: allow(Ecto.UUID).to accept(:generate, fn() -> "6a79129d-0990-46cb-9b89-893c48bf2173" end)

    it do: expect(described_module.build_event_message(payload, to)).to eq(expected_message)
  end
end
