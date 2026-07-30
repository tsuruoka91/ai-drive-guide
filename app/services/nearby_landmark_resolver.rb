require "json"
require "net/http"
require "uri"

class NearbyLandmarkResolver
  Landmark = Struct.new(:name, :wikipedia_title, keyword_init: true)
  ENDPOINT = URI("https://overpass-api.de/api/interpreter")
  SEARCH_RADIUS_METERS = 600
  MAXIMUM_LANDMARKS = 5
  MINIMUM_REQUEST_INTERVAL = 1.1

  @rate_limit_mutex = Mutex.new
  @last_request_at = Time.at(0)
  @cache = ActiveSupport::Cache::MemoryStore.new

  class << self
    attr_reader :rate_limit_mutex, :cache
    attr_accessor :last_request_at

    def call(latitude:, longitude:)
      new.call(latitude:, longitude:)
    end
  end

  def initialize(fetcher: nil, throttle: true, cache: self.class.cache)
    @fetcher = fetcher
    @throttle = throttle
    @cache = cache
  end

  def call(latitude:, longitude:)
    cache_key = "nearby-landmarks/#{latitude.round(3)}/#{longitude.round(3)}"
    cached_landmarks = @cache&.read(cache_key)
    return cached_landmarks if cached_landmarks.present?

    throttle! if @throttle

    body = @fetcher ? @fetcher.call(query_for(latitude:, longitude:)) : perform_request(latitude:, longitude:)
    return [] unless body

    landmarks = JSON.parse(body).fetch("elements", []).filter_map do |element|
      tags = element.fetch("tags", {})
      name = tags["name"]
      next if name.blank?

      Landmark.new(name:, wikipedia_title: wikipedia_title_for(tags))
    end.uniq(&:name).first(MAXIMUM_LANDMARKS)
    @cache&.write(cache_key, landmarks, expires_in: 5.minutes) if landmarks.any?
    landmarks
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

  def wikipedia_title_for(tags)
    reference = tags["wikipedia:ja"] || tags["wikipedia"]
    return unless reference

    reference.delete_prefix("ja:") if reference.start_with?("ja:")
  end
end
