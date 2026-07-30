module ExternalHttpRetry
  TRANSIENT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError].freeze

  private

  def with_external_http_retry
    yield
  rescue *TRANSIENT_ERRORS
    sleep 1
    yield
  end
end
