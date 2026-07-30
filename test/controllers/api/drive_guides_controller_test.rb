require "test_helper"

class Api::DriveGuidesControllerTest < ActionDispatch::IntegrationTest
  test "returns the fixed guide for valid coordinates" do
    post "/api/drive_guides", params: { latitude: 35.681236, longitude: 139.767125 }, as: :json

    assert_response :success
    assert_equal "安全運転で出発しましょう。周囲をよく確認してください。", response.parsed_body["guide"]
  end

  test "rejects coordinates outside their valid ranges" do
    post "/api/drive_guides", params: { latitude: 91, longitude: 139.767125 }, as: :json

    assert_response :unprocessable_entity
    assert_equal "位置情報を正しく受信できませんでした。", response.parsed_body["error"]
  end
end
