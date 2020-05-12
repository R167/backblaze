# frozen_string_literal: true

module Backblaze::B2
  class FileVersion < Base
    include Resource

    ATTRIBUTES = %w(accountId action bucketId contentLength contentSha1 contentType fileId fileInfo fileName uploadTimestamp)

    create_attributes ATTRIBUTES

    alias_method :name, :file_name
    alias_method :id, :file_id

    def initialize(api=nil, bucket: nil, attrs: {})
      if bucket.is_a?(Bucket)
        @bucket = bucket
      else
        bucket_params = attrs.slice(:bucket_name, :bucket_id)
        if bucket.is_a?(Hash)
          bucket_params.merge!(bucket)
        end

      end

      super(api, attrs: attrs)
    end

    def all_versions!

    end

    ##
    # Call B2 to get the latest version of this file if one exists
    # @return [FileVersion, nil] The latest version of the file, or nil if none
    def latest!
      result = self.class.find_files(bucket: bucket, count: 1, prefix: name, start_at: name).first
      result if result && result.name == name
    end

    def bucket
      @bucket
    end

    class << self
      ##
      # Finds up to `count` files in the provided bucket
      #
      # List out files in a bucket. This operation performs the lookup in batches. When no block is passed, an array
      # of all fetched files is returned. When passed a block, each file is yielded to it.
      #
      # @example Print the name of all files in the bucket
      #   b = Backblaze::B2.buckets.first
      #   Backblaze::B2::File.find_files(bucket: b, count: :all) do |file|
      #     puts file.file_name
      #   end
      #
      # @param [Bucket] bucket Bucket to list out the files in
      # @param start_at First file to start searching for. Not usually to useful
      # @param [Numeric, :all] count Stop after fetching this many files. When passed a positive value, this is the case.
      #   If you want no limit on the results returned, use the special value `:all`. This will set count to infinity.
      # @param batch_size Number of results to fetch per api call. Defaults to the transaction max. If you are performing
      #   work where you need files fetched very quickly, consider reducing.
      # @param prefix Only files with this prefix in the bucket will be returned
      # @param delimiter Split files and folders on this character. (see Api#list_file_names)
      # @overload find_files(..., &block)
      #   @yield When included, used to process each file
      #   @yieldparam [FileVersion] file Each found file
      #   @return [void] No meaningful return when called with block
      # @overload find_files(...)
      #   @return [Array<FileVersion>] List of all the files found within our bounds
      def find_files(bucket:, count:, start_at: nil, batch_size: 1000, prefix: nil, delimiter: nil)
        files = []

        api_list(bucket.api, :list_file_names, bucket.id,
            start_at: {name: start_at},
            count: count,
            prefix: prefix,
            delimiter: delimiter) do |file|
          f = new(bucket.api, bucket: bucket, attrs: file)
          if block_given?
            yield f
          else
            files << f
          end
        end
        files
      end

    end

  end
end
