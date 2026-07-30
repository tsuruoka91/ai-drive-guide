require "test_helper"

class Api::DriveGuidesControllerTest < ActionDispatch::IntegrationTest
  test "returns the fixed guide for valid coordinates" do
    with_location_label("丸の内、千代田区") do
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

  def with_location_label(label)
    singleton_class = LocationLabelResolver.singleton_class
    original = singleton_class.instance_method(:call)
    singleton_class.define_method(:call) { |**| label }
    yield
  ensure
    singleton_class.define_method(:call, original)
  end
end
