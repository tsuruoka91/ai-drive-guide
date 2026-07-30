require "test_helper"

class WikipediaSummaryResolverTest < ActiveSupport::TestCase
  test "returns a plain-text introductory extract" do
    request_uri = nil
    resolver = WikipediaSummaryResolver.new(
      fetcher: lambda do |uri|
        request_uri = uri
        { query: { pages: [{ extract: "東京スカイツリーは、東京都墨田区にある電波塔です。" }] } }.to_json
      end
    )

    summary = resolver.call(title: "東京スカイツリー")

    assert_equal "東京スカイツリーは、東京都墨田区にある電波塔です。", summary
    assert_includes request_uri.query, "exsentences=3"
  end

  test "returns nil when no extract is available" do
    resolver = WikipediaSummaryResolver.new(fetcher: ->(*) { { query: { pages: [] } }.to_json })

    assert_nil resolver.call(title: "存在しない項目")
  end
end
