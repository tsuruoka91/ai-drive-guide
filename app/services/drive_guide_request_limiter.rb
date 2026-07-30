require "digest"

class DriveGuideRequestLimiter
  LIMIT = 3
  WINDOW = 1.minute

  @cache = ActiveSupport::Cache::MemoryStore.new
  @mutex = Mutex.new

  class << self
    attr_reader :cache, :mutex

    def allow?(ip_address)
      key = "drive-guide-request/#{Digest::SHA256.hexdigest(ip_address.to_s)}"

      mutex.synchronize do
        count = cache.read(key).to_i
        return false if count >= LIMIT

        cache.write(key, count + 1, expires_in: WINDOW)
        true
      end
    end

    def reset!
      cache.clear
    end
  end
end
