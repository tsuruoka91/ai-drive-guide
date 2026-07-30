require "test_helper"

class DriveGuideGeneratorTest < ActiveSupport::TestCase
  test "returns the fixed MVP guide" do
    guide = DriveGuideGenerator.new(api_key: nil).call(latitude: 35.681236, longitude: 139.767125)

    assert_equal "安全運転で出発しましょう。周囲をよく確認してください。", guide
  end

  test "uses the Responses API when an API key is configured" do
    request = nil
    response = Struct.new(:output_text).new("周囲をよく確認して、安全運転で進みましょう。")
    responses = Object.new
    responses.define_singleton_method(:create) do |**arguments|
      request = arguments
      response
    end
    client = Struct.new(:responses).new(responses)

    guide = DriveGuideGenerator.new(client:, api_key: "test-key", model: "test-model").call(
      latitude: 35.681236,
      longitude: 139.767125,
      location: "丸の内、千代田区",
      landmarks: ["東京駅"],
      history: "東京駅は、東京都千代田区にある鉄道駅です。"
    )

    assert_equal "周囲をよく確認して、安全運転で進みましょう。", guide
    assert_equal "test-model", request[:model]
    assert_includes request[:input], "現在地の周辺: 丸の内、千代田区"
    assert_includes request[:input], "近隣の実在スポット: 東京駅"
    assert_includes request[:input], "確認済みの歴史・概要: 東京駅は、東京都千代田区にある鉄道駅です。"
  end

  test "raises a safe error when the API response is empty" do
    response = Struct.new(:output_text).new("")
    responses = Struct.new(:response) do
      def create(**)
        response
      end
    end.new(response)
    client = Struct.new(:responses).new(responses)

    assert_raises(DriveGuideGenerator::GenerationError) do
      DriveGuideGenerator.new(client:, api_key: "test-key").call(latitude: 35.681, longitude: 139.767)
    end
  end
end
