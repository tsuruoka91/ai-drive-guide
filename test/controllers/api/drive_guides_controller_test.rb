require "test_helper"

class Api::DriveGuidesControllerTest < ActionDispatch::IntegrationTest
  test "returns the fixed guide for valid coordinates" do
    with_location_context(location: "丸の内、千代田区", landmarks: ["東京駅"] ) do
      original_api_key = ENV.delete("OPENAI_API_KEY")
      post "/api/drive_guides", params: { latitude: 35.681236, longitude: 139.767125 }, as: :json
    ensure
      ENV["OPENAI_API_KEY"] = original_api_key if original_api_key
    end

    assert_response :success
    assert_equal "安全運転で出発しましょう。周囲をよく確認してください。", response.parsed_body["guide"]
    assert_equal "丸の内、千代田区", response.parsed_body["location"]
  end

  test "rejects coordinates outside their valid ranges" do
    post "/api/drive_guides", params: { latitude: 91, longitude: 139.767125 }, as: :json

    assert_response :unprocessable_entity
    assert_equal "位置情報を正しく受信できませんでした。", response.parsed_body["error"]
  end

  private

  def with_location_context(location:, landmarks:)
    label_singleton_class = LocationLabelResolver.singleton_class
    landmark_singleton_class = NearbyLandmarkResolver.singleton_class
    original_label = label_singleton_class.instance_method(:call)
    original_landmarks = landmark_singleton_class.instance_method(:call)
    label_singleton_class.define_method(:call) { |**| location }
    landmark_singleton_class.define_method(:call) do |**|
      landmarks.map { |name| NearbyLandmarkResolver::Landmark.new(name:, wikipedia_title: nil) }
    end
    yield
  ensure
    label_singleton_class.define_method(:call, original_label)
    landmark_singleton_class.define_method(:call, original_landmarks)
  end
end
