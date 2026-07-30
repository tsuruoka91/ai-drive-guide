require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the initial screen" do
    get root_url

    assert_response :success
    assert_select "h1", "AI Drive Guide"
  end
end
