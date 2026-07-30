require "test_helper"

class DriveGuideGeneratorTest < ActiveSupport::TestCase
  test "returns the fixed MVP guide" do
    guide = DriveGuideGenerator.call(latitude: 35.681236, longitude: 139.767125)

    assert_equal "安全運転で出発しましょう。周囲をよく確認してください。", guide
  end
end
