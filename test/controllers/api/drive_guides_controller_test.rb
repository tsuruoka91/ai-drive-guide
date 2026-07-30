require "test_helper"

class Api::DriveGuidesControllerTest < ActionDispatch::IntegrationTest
  test "returns the fixed guide for valid coordinates" do
    begin
      original_api_key = ENV.delete("OPENAI_API_KEY")
      post "/api/drive_guides", params: { latitude: 35.681236, longitude: 139.767125 }, as: :json
    ensure
      ENV["OPENAI_API_KEY"] = original_api_key if original_api_key
    end

    assert_response :success
    assert_equal "ドライブの時間を、のんびりお楽しみください。", response.parsed_body["guide"]
    assert_equal "どらいぶの じかんを、のんびり おたのしみください。", response.parsed_body["speech_text"]
    assert_not response.parsed_body.key?("location")
  end

  test "rejects coordinates outside their valid ranges" do
    post "/api/drive_guides", params: { latitude: 91, longitude: 139.767125 }, as: :json

    assert_response :unprocessable_entity
    assert_equal "位置情報を正しく受信できませんでした。", response.parsed_body["error"]
  end
end
