require "json"
require "net/http"
require "uri"

class LocationLabelResolver
  ENDPOINT = "https://nominatim.openstreetmap.org/reverse".freeze
  MINIMUM_REQUEST_INTERVAL = 1.1
  DEFAULT_USER_AGENT = "ai-drive-guide/0.1".freeze

  @rate_limit_mutex = Mutex.new
  @last_request_at = Time.at(0)

  class << self
    attr_reader :rate_limit_mutex
    attr_accessor :last_request_at

    def call(latitude:, longitude:)
      new.call(latitude:, longitude:)
    end
  end

  def initialize(fetcher: nil, throttle: true)
    @fetcher = fetcher
    @throttle = throttle
  end

  def call(latitude:, longitude:)
    throttle! if @throttle

    response = @fetcher ? @fetcher.call(uri_for(latitude:, longitude:), headers) : perform_request(latitude:, longitude:)
    return unless response.is_a?(Net::HTTPSuccess)

    label_for(JSON.parse(response.body))
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, URI::InvalidURIError
    nil
  end

  private

  def uri_for(latitude:, longitude:)
    URI("#{ENDPOINT}?#{URI.encode_www_form(
      format: "jsonv2",
      lat: latitude.round(3),
      lon: longitude.round(3),
      zoom: 16,
      layer: "address",
      "accept-language": "ja"
    )}")
  end

  def headers
    { "User-Agent" => ENV.fetch("NOMINATIM_USER_AGENT", DEFAULT_USER_AGENT) }
  end

  def perform_request(latitude:, longitude:)
    uri = uri_for(latitude:, longitude:)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 3) do |http|
      http.get(uri.request_uri, headers)
    end
  end

  def label_for(payload)
    address = payload.fetch("address", {})
    [
      address["road"],
      address["neighbourhood"] || address["suburb"],
      address["city"] || address["town"] || address["village"]
    ].compact.uniq.join("、").presence
  end

  def throttle!
    self.class.rate_limit_mutex.synchronize do
      wait = MINIMUM_REQUEST_INTERVAL - (Time.current - self.class.last_request_at)
      sleep(wait) if wait.positive?
      self.class.last_request_at = Time.current
    end
  end
end
