require "test_helper"

class DriveGuideRequestLimiterTest < ActiveSupport::TestCase
  setup { DriveGuideRequestLimiter.reset! }

  test "allows three requests per IP address within the time window" do
    assert DriveGuideRequestLimiter.allow?("203.0.113.10")
    assert DriveGuideRequestLimiter.allow?("203.0.113.10")
    assert DriveGuideRequestLimiter.allow?("203.0.113.10")
    assert_not DriveGuideRequestLimiter.allow?("203.0.113.10")
  end

  test "tracks each IP address separately" do
    3.times { DriveGuideRequestLimiter.allow?("203.0.113.10") }

    assert DriveGuideRequestLimiter.allow?("203.0.113.11")
  end
end
