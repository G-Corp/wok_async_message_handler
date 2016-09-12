defmodule WokAsyncMessageHandler.Helpers.TestMessageSpec do
  use ESpec

  describe "#build_wok_message" do
    before do: allow(:kafe).to accept(:partitions, fn(_) -> [0] end)
    it do: expect(described_module.build_wok_message(
            "topic",
            "key",
            "from",
            "to",
            %{version: 1, payload: %{k: "v"}}
           ))
           .to eq("g2gGZAAHd29rX21zZ2gHZAAHbWVzc2FnZWQACXVuZGVmaW5"
            <> "lZGQACXVuZGVmaW5lZGQACXVuZGVmaW5lZHQAAAAAZAAJdW5kZ"
            <> "WZpbmVkZAAJdW5kZWZpbmVkaAZkAAx3b2tfbXNnX3Jlc3BkAAR0"
            <> "cnVlbQAAAARmcm9tbQAAAAJ0b20AAAAFdG9waWNtAAAAI1t7InZl"
            <> "cnNpb24iOjEsInBheWxvYWQiOnsiayI6InYifX1dZAAJdW5kZWZp"
            <> "bmVkZAAJdW5kZWZpbmVkZAAJdW5kZWZpbmVk")

  end

  describe "#build_event_message" do

    let :payload, do: %{"name" => "bob", "age" => 69}
    let :from, do: "from_bot"

    before do: allow(Ecto.UUID).to accept(:generate, fn() -> "6a79129d-0990-46cb-9b89-893c48bf2173" end)

    context "when no options" do
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
      "topic",
      :undefined,
      :undefined,
      :undefined,
      :undefined,
      :undefined,
      :undefined
    }

      it do: expect(described_module.build_event_message(
            payload,
            from,
            23
          )).to eq(expected_message)
    end

    context "when options" do
      let :expected_message, do: {
      :message_transfert, :undefined, {
        :wok_msg, {
          :message,
          "6a79129d-0990-46cb-9b89-893c48bf2173",
          "to_bot",
          "from_bot",
          %{},
          %{message_id: 23},
          "[{\"version\":2,\"payload\":{\"name\":\"bob\",\"age\":69},\"metadata\":{\"seb_error\":true}}]"
        },
        {:wok_msg_resp, false, :undefined, :undefined, :undefined, "" },
        :undefined, :undefined, :undefined
      },
      999,
      "my_topic",
      :undefined,
      :undefined,
      :undefined,
      :undefined,
      :undefined,
      :undefined
    }
      it do: expect(described_module.build_event_message(
            payload,
            from,
            23,
            [metadata: %{seb_error: true}, partition: 999, topic: "my_topic", version: 2]
          )).to eq(expected_message)
    end
  end
end
