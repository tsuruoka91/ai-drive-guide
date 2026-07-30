require "json"
require "net/http"
require "uri"

class WikipediaSummaryResolver
  ENDPOINT = "https://ja.wikipedia.org/w/api.php".freeze
  DEFAULT_USER_AGENT = "ai-drive-guide/0.1".freeze

  def self.call(title:)
    new.call(title:)
  end

  def initialize(fetcher: nil)
    @fetcher = fetcher
  end

  def call(title:)
    return if title.blank?

    body = @fetcher ? @fetcher.call(uri_for(title)) : perform_request(title)
    return unless body

    JSON.parse(body).dig("query", "pages", 0, "extract").to_s.strip.presence
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, URI::InvalidURIError
    nil
  end

  private

  def uri_for(title)
    URI("#{ENDPOINT}?#{URI.encode_www_form(
      action: "query",
      prop: "extracts",
      exintro: 1,
      explaintext: 1,
      exsentences: 3,
      redirects: 1,
      titles: title,
      format: "json",
      formatversion: 2
    )}")
  end

  def perform_request(title)
    uri = uri_for(title)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 5) do |http|
      http.get(uri.request_uri, { "User-Agent" => ENV.fetch("WIKIPEDIA_USER_AGENT", DEFAULT_USER_AGENT) })
    end
    response.body if response.is_a?(Net::HTTPSuccess)
  end
end
