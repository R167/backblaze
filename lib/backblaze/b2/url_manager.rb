module Backblaze::B2

  ##
  # A mostly internal class, utilized for managing upload URLs
  class UrlManager
    include Singleton
    include Backblaze::Utils

    def initialize
      @monitor = Monitor.new
      @buckets = Hash.new
    end

    ##
    # Main method. Call with a bucket id and it will block until one of the upload
    # URLs for your bucket is available.
    # @param [String] bucket_id id of the bucket we are using
    # @param [Integer] attempts retry attempts for when errors are encountered
    # @param [Boolean] wait whether or not to block for the queue
    # @yield [Backblaze::B2::UploadUrl] yields an UploadUrl to be used in the request
    # @return [nil]
    def lease_url(bucket_id:, attempts: 1, wait: true, &block)
      url = nil
      @monitor.synchronize do
        bucket = get_bucket(bucket_id)
        while bucket[:queue].length > 0 && url.nil? && wait
          url = bucket[:queue].pop
          if url.expired?
            bucket[:current] -= 1
            url = nil
          end
        end
        if bucket[:current] < bucket[:limit]
          url = UploadUrl.new(bucket_id: bucket_id)
          @buckets[bucket_id][:current] += 1
        end
      end
      url ||= get_bucket(bucket_id)[:queue].pop(wait)
      retry_block(attempts: attempts) do
        url.renew
        block.call(url)
      end
    ensure
      @buckets[bucket_id][:queue] << url if url
    end

    def add_bucket(bucket_id:, max_uploads:)
    end

    private

    def read_bucket(bucket_id, concurrency: nil)
      concurrency ||= Backblaze::B2.default_concurrency
      if @buckets[bucket_id]
        @buckets[bucket_id]
      else
        @monitor.synchronize do
          @buckets[bucket_id] = {
            limit: concurrency,
            current: 0,
            queue: Queue.new
          }
          @buckets[bucket_id]
        end
      end
    end
  end

  class UploadUrl < Base
    attr_reader :url, :token, :bucket_id, :expiration

    ONE_DAY = 60 * 60 * 24

    def initialize(bucket_id:)
      @bucket_id = bucket_id
      @expiration = Time.now + ONE_DAY
    end

    def expired?
      expiration < Time.now
    end

    def renew
      if url.nil? || token.nil? || expiration < Time.now
        response = post('/b2_get_upload_url', body: {bucketId: bucket_id}.to_json)
        raise Backblaze::BucketError.new(response) unless response.code / 100 == 2
        @url = response['uploadUrl']
        @token = response['authorizationToken']
        @expiration = Time.now + ONE_DAY
      end
    end
  end
end
