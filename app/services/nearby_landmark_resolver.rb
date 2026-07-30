require "json"
require "net/http"
require "uri"

class NearbyLandmarkResolver
  ENDPOINT = URI("https://overpass-api.de/api/interpreter")
  SEARCH_RADIUS_METERS = 600
  MAXIMUM_LANDMARKS = 5
  MINIMUM_REQUEST_INTERVAL = 1.1

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

    body = @fetcher ? @fetcher.call(query_for(latitude:, longitude:)) : perform_request(latitude:, longitude:)
    return [] unless body

    JSON.parse(body).fetch("elements", []).filter_map { |element| element.dig("tags", "name") }.uniq.first(MAXIMUM_LANDMARKS)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, URI::InvalidURIError
    []
  end

  private

  def query_for(latitude:, longitude:)
    <<~OVERPASS
      [out:json][timeout:10];
      (
        nwr(around:#{SEARCH_RADIUS_METERS},#{latitude.round(3)},#{longitude.round(3)})["name"]["tourism"~"attraction|museum|gallery|viewpoint|zoo|theme_park"];
        nwr(around:#{SEARCH_RADIUS_METERS},#{latitude.round(3)},#{longitude.round(3)})["name"]["historic"];
        nwr(around:#{SEARCH_RADIUS_METERS},#{latitude.round(3)},#{longitude.round(3)})["name"]["leisure"~"park|garden"];
        nwr(around:#{SEARCH_RADIUS_METERS},#{latitude.round(3)},#{longitude.round(3)})["name"]["railway"="station"];
      );
      out center;
    OVERPASS
  end

  def perform_request(latitude:, longitude:)
    request = Net::HTTP::Post.new(ENDPOINT, {
      "User-Agent" => ENV.fetch("OVERPASS_USER_AGENT", "ai-drive-guide/0.1"),
      "Content-Type" => "text/plain"
    })
    request.body = query_for(latitude:, longitude:)

    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 2, read_timeout: 10) do |http|
      http.request(request)
    end
    response.body if response.is_a?(Net::HTTPSuccess)
  end

  def throttle!
    self.class.rate_limit_mutex.synchronize do
      wait = MINIMUM_REQUEST_INTERVAL - (Time.current - self.class.last_request_at)
      sleep(wait) if wait.positive?
      self.class.last_request_at = Time.current
    end
  end
end
