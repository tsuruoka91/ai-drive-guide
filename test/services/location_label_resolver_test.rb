require "test_helper"

class LocationLabelResolverTest < ActiveSupport::TestCase
  test "returns a compact Japanese location label" do
    response = Struct.new(:body).new({
      "address" => {
        "road" => "丸の内一丁目",
        "neighbourhood" => "丸の内",
        "city" => "千代田区"
      }
    }.to_json)
    response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPSuccess || super(klass) }
    request_uri = nil
    request_headers = nil
    resolver = LocationLabelResolver.new(
      throttle: false,
      fetcher: lambda do |uri, headers|
        request_uri = uri
        request_headers = headers
        response
      end
    )

    label = resolver.call(latitude: 35.681236, longitude: 139.767125)

    assert_equal "丸の内一丁目、丸の内、千代田区", label
    assert_includes request_uri.query, "lat=35.681"
    assert_equal "ai-drive-guide/0.1", request_headers["User-Agent"]
  end

  test "returns nil when the provider returns an error" do
    response = Struct.new(:body).new("")
    response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPServerError || super(klass) }
    resolver = LocationLabelResolver.new(fetcher: ->(*) { response }, throttle: false)

    assert_nil resolver.call(latitude: 35.681, longitude: 139.767)
  end

  test "retries once after a temporary network error" do
    attempts = 0
    resolver = LocationLabelResolver.new(
      throttle: false,
      fetcher: lambda do |*|
        attempts += 1
        raise Net::ReadTimeout if attempts == 1

        response = Struct.new(:body).new({ address: { city: "千代田区" } }.to_json)
        response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPSuccess || super(klass) }
        response
      end
    )
    resolver.define_singleton_method(:sleep) { |_| }

    assert_equal "千代田区", resolver.call(latitude: 35.681, longitude: 139.767)
    assert_equal 2, attempts
  end
end
