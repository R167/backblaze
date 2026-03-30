module Backblaze::B2
  class Base
    include HTTParty
    include Backblaze::Utils

    MAX_RETRIES = 5

    format :json

    [:get, :head, :post, :put].each do |req|
      define_method(req) do |path, options={}, &block|
        self.class.send(req, path, options, &block)
      end
    end

    # Execute a block with automatic retry on transient B2 errors.
    # Handles token expiry (re-authenticates), Retry-After headers,
    # and exponential backoff for retryable status codes (408, 429, 500, 503).
    #
    # @param max_retries [Integer] maximum number of retries (default: MAX_RETRIES)
    # @yield the block to execute
    # @return the block's return value
    # @raise [Backblaze::RequestError] if all retries are exhausted
    def self.with_retry(max_retries: MAX_RETRIES)
      attempts = 0
      begin
        yield
      rescue Backblaze::RequestError => e
        raise unless e.retryable?
        attempts += 1
        raise if attempts > max_retries

        if e.token_expired?
          Backblaze::B2.reauthorize!
          Base.headers 'Authorization' => Backblaze::B2.token, 'Content-Type' => 'application/json'
        end

        delay = e.retry_after || [1 * (2 ** (attempts - 1)), 64].min
        sleep(delay)
        retry
      end
    end

    def with_retry(max_retries: MAX_RETRIES, &block)
      self.class.with_retry(max_retries: max_retries, &block)
    end

    protected

    def file_versions(bucket_id:, limit:, double_check_server:, file_name: nil, &block)
      retrieve_count = (double_check_server ? 0 : -1)
      files = file_list(bucket_id: bucket_id, limit: limit, retrieved: retrieve_count, file_name: file_name, first_file: nil, start_field: 'startFileId')

      files.map! do |f|
        block.nil? ? Backblaze::B2::FileVersion.new(**f) : block.call(f)
      end
      files.compact
    end

    def file_list(limit:, retrieved:, first_file:, start_field:, bucket_id:, file_name: nil, first: true, prefix: nil, delimiter: nil)
      params = {'bucketId' => bucket_id}
      if limit == -1
        params['maxFileCount'] = 10000
      elsif limit > 10000
        params['maxFileCount'] = 10000
      elsif limit > 0
        params['maxFileCount'] = limit
      else
        return []
      end
      if first_file.nil?
        if file_name && start_field == 'startFileId' && first
          params['startFileName'] = file_name
        end
      else
        params[start_field] = first_file
      end

      # B2 prefix/delimiter support for directory-style listing
      params['prefix'] = prefix if prefix
      params['delimiter'] = delimiter if delimiter

      response = post("/b2_list_file_#{start_field == 'startFileName' ? 'names' : 'versions'}", body: params.to_json)

      raise Backblaze::FileError.new(response) unless response.code == 200

      files = response['files']
      halt = false
      files.map! do |f|
        if halt
          nil
        else
          ret = normalize_file_hash(f)
          halt = true if file_name && file_name != ret[:file_name]
          halt ? nil : ret
        end
      end.compact!

      retrieved = retrieved + files.size if retrieved >= 0
      if limit > 0
        limit = limit - (retrieved >= 0 ? files.size : 10000)
        limit = 0 if limit < 0
      end

      next_item = response[start_field.sub('start', 'next')]

      if (limit > 0 || limit == -1) && !!next_item && !halt
        files.concat file_list(
          first_file: next_item,
          limit: limit,
          retrieved: retrieved,
          start_field: start_field,
          bucket_id: bucket_id,
          first: false,
          prefix: prefix,
          delimiter: delimiter
        )
      else
        files
      end
    end

    private

    # Normalize a file hash from the API response.
    # Handles v2+ using contentLength instead of size.
    def normalize_file_hash(f)
      ret = response_to_hash(f)
      # v2+ returns contentLength instead of size
      if ret[:content_length] && !ret[:size]
        ret[:size] = ret[:content_length]
      end
      ret
    end
  end
end
