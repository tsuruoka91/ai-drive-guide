require "test_helper"

class DriveGuideGeneratorTest < ActiveSupport::TestCase
  test "returns the fixed MVP guide" do
    guide = DriveGuideGenerator.new(api_key: nil).call(latitude: 35.681236, longitude: 139.767125)

    assert_equal "ドライブの時間を、のんびりお楽しみください。", guide.display_text
    assert_equal "どらいぶの じかんを、のんびり おたのしみください。", guide.speech_text
  end

  test "uses the Responses API when an API key is configured" do
    request = nil
    response = Struct.new(:output_text).new({
      display_text: "東京駅の近くを走行しています。周囲をよく確認して、安全運転で進みましょう。",
      speech_text: "とうきょうえきの ちかくを そうこうしています。しゅういを よく かくにんして、あんぜんうんてんで すすみましょう。"
    }.to_json)
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

    assert_equal "東京駅の近くを走行しています。周囲をよく確認して、安全運転で進みましょう。", guide.display_text
    assert_equal "とうきょうえきの ちかくを そうこうしています。しゅういを よく かくにんして、あんぜんうんてんで すすみましょう。", guide.speech_text
    assert_equal "test-model", request[:model]
    assert_equal "json_schema", request.dig(:text, :format, :type)
    assert_equal "おおよその現在地: 緯度 35.681, 経度 139.767", request[:input]
    assert_includes request[:instructions], "娯楽目的の創作"
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

  test "raises a safe error when speech text contains kanji" do
    response = Struct.new(:output_text).new({ display_text: "東京駅です。", speech_text: "東京駅です。" }.to_json)
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

  test "raises a safe error when display text contains no kanji" do
    response = Struct.new(:output_text).new({
      display_text: "とうきょうえきの ちかくを そうこうしています。",
      speech_text: "とうきょうえきの ちかくを そうこうしています。"
    }.to_json)
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
