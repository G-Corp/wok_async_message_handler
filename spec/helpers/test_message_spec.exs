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
           .to eq("g2gIZAALd29rX21lc3NhZ2VoDGQAA21zZ2QACXVuZGVmaW5lZGQACXVuZGVm"
                  <> "aW5lZGQACXVuZGVmaW5lZGQACXVuZGVmaW5lZGQACXVuZGVmaW5lZHQAA"
                  <> "AAAZAAJdW5kZWZpbmVkZAAJdW5kZWZpbmVkZAAJdW5kZWZpbmVkZAAJdW"
                  <> "5kZWZpbmVkZAAJdW5kZWZpbmVkaAxkAANtc2dkAAl1bmRlZmluZWRtAAA"
                  <> "ABGZyb21tAAAAAnRvZAAJdW5kZWZpbmVkbQAAACNbeyJ2ZXJzaW9uIjox"
                  <> "LCJwYXlsb2FkIjp7ImsiOiJ2In19XXQAAAAAZAAJdW5kZWZpbmVkZAAJd"
                  <> "W5kZWZpbmVkZAAJdW5kZWZpbmVkbQAAAAV0b3BpY2QACXVuZGVmaW5lZG"
                  <> "QACXVuZGVmaW5lZGQACXVuZGVmaW5lZHQAAAAAZAAEdHJ1ZWQACXVuZGV"
                  <> "maW5lZA==")
  end

  describe "#build_event_message" do

    let :payload, do: %{"name" => "bob", "age" => 69}
    let :from, do: "from_bot"

    before do
      allow(:uuid).to accept(:uuid4, fn() -> "6a79129d-0990-46cb-9b89-893c48bf2173" end)
      allow(:uuid).to accept(:to_string, fn(x) -> x end)
    end

    context "when no options" do
      let :expected_message, do: 
        {:wok_message, 
         {:msg, 
          "6a79129d-0990-46cb-9b89-893c48bf2173", 
          "from_bot", 
          "to_bot", 
          %{message_id: 23}, 
          "[{\"version\":1,\"payload\":{\"name\":\"bob\",\"age\":69}}]", 
          %{}, 
          0, 
          :undefined, 
          %{"age" => 69, "name" => "bob"}, "topic", 1}, 
        {:msg, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined, 
         %{}, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined}, 
        :undefined, 
        :undefined, 
        %{}, 
        false, 
        :undefined}

      it do: expect(described_module.build_event_message(
            payload,
            from,
            23
          )).to eq(expected_message)
    end

    context "when options" do
      let :expected_message, do: 
        {:wok_message, 
         {:msg, 
          "6a79129d-0990-46cb-9b89-893c48bf2173", 
          "from_bot", 
          "to_bot", 
          %{message_id: 23}, 
          "[{\"version\":2,\"payload\":{\"name\":\"bob\",\"age\":69},\"metadata\":{\"seb_error\":true}}]", 
          %{}, 
          0, 
          :undefined, 
          %{"age" => 69, "name" => "bob"}, 
          "my_topic", 
          999}, 
        {:msg, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined, 
         %{}, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined, 
         :undefined}, 
        :undefined, 
        :undefined, 
        %{}, 
        false, 
        :undefined}
      it do: expect(described_module.build_event_message(
            payload,
            from,
            23,
            [metadata: %{seb_error: true}, partition: 999, topic: "my_topic", version: 2]
          )).to eq(expected_message)
    end
  end
end
