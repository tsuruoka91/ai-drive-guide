require "test_helper"

class NearbyLandmarkResolverTest < ActiveSupport::TestCase
  test "returns up to five unique named landmarks" do
    query = nil
    resolver = NearbyLandmarkResolver.new(
      throttle: false,
      fetcher: lambda do |overpass_query|
        query = overpass_query
        {
          elements: [
            { tags: { name: "東京スカイツリー", tourism: "attraction" } },
            { tags: { name: "すみだ水族館", tourism: "aquarium" } },
            { tags: { name: "東京スカイツリー", tourism: "attraction" } },
            { tags: {} }
          ]
        }.to_json
      end
    )

    landmarks = resolver.call(latitude: 35.710063, longitude: 139.8107)

    assert_equal ["東京スカイツリー", "すみだ水族館"], landmarks
    assert_includes query, "around:600,35.71,139.811"
  end

  test "returns an empty array when the provider response is invalid" do
    resolver = NearbyLandmarkResolver.new(fetcher: ->(*) { "not json" }, throttle: false)

    assert_equal [], resolver.call(latitude: 35.681, longitude: 139.767)
  end
end
