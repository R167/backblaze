# frozen_string_literal: true

module Backblaze::B2
  class FileVersion < Base
    include Resource

    ATTRIBUTES = %w(accountId action bucketId contentLength contentSha1 contentType fileId fileInfo fileName uploadTimestamp)
    CONFIG = %i(content_type file_info file_name)

    create_attributes ATTRIBUTES

    alias_method :name, :file_name
    alias_method :id, :file_id
    alias_method :size, :content_length

    def initialize(account = nil, bucket: nil, attrs: {})
      if bucket.is_a?(Bucket)
        @bucket = bucket
      else
        bucket_params = attrs.slice(:bucket_name, :bucket_id)
        if bucket.is_a?(Hash)
          bucket_params.merge!(bucket)
        end

      end

      super(account, attrs: attrs)
    end

    # @return [Array<FileVersion>] List of all ovrsions of this file
    def all_versions!
      self.class.find_versions_of_file(bucket: bucket, file_name: file_name)
    end

    ##
    # Call B2 to get the latest version of this file if one exists
    # @return [FileVersion, nil] The latest version of the file, or nil if none
    def latest!
      result = self.class.find_files(bucket: bucket, count: 1, prefix: name, start_at: name).first
      result if result && result.name == name
    end

    # @return [Bucket] The file's bucket
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
      # @param start_at First file to start searching for. Not usually too useful
      # @param [Numeric, :all] count Stop after fetching this many files. When passed a positive value, this is the case.
      #   If you want no limit on the results returned, use the special value `:all`. This will set count to infinity.
      # @param batch_size Number of results to fetch per api call. Defaults to the transaction max. If you are performing
      #   work where you need files fetched very quickly, consider reducing.
      # @param prefix Only files with this prefix in the bucket will be returned
      # @param delimiter Split files and folders on this character. (see Api#list_file_names)
      # @overload find_files(..., &block)
      #   @yield When included, used to process each file
      #   @yieldparam [FileVersion] file Each found file
      #   @return [Hash] iterator information about this run
      # @overload find_files(...)
      #   @return [Array<FileVersion>] List of all the files found within our bounds
      def find_files(bucket:, count:, start_at: nil, batch_size: 1000, prefix: nil, delimiter: nil)
        files = []

        api_list(bucket.account, :list_file_names, bucket.id,
            start_at: {name: start_at},
            count: count,
            prefix: prefix,
            delimiter: delimiter) do |file|
          f = new(bucket.account, bucket: bucket, attrs: file)
          if block_given?
            yield f
          else
            files << f
          end
        end
        files
      end

      ##
      # Find all file versions. Similar to {.find_files}, except this returns any file versions
      # @param (see .find_files)
      # @return [Hash, Array<FileVersion>] Hash on iterator info or list of files when no block is passed
      # @see .find_files
      def find_file_versions(bucket:, count:, start_at: nil, batch_size: 1000, prefix: nil, delimiter: nil)
        files = []

        api_list(bucket.account, :list_file_versions, bucket.id,
            start_at: start_at,
            count: count,
            prefix: prefix,
            delimiter: delimiter) do |file|
          f = new(bucket.account, bucket: bucket, attrs: file)
          if block_given?
            yield f
          else
            files << f
          end
        end
        files
      end

      ##
      # Find all versions of a specific file.
      #
      # Refer to {.find_files} for more information on how to use the block parameters
      #
      # @param bucket (see .find_files)
      # @param file_name Name of the file to search for
      # @param count Max number of results returned. Since we looking at one file here, this defaults to call. Refer to
      #   {.find_files} for what that means
      # @return (see .find_file_versions)
      def find_versions_of_file(bucket:, file_name:, count: :all)
        files = []

        api_list(bucket.account, :list_file_versions, bucket.id,
            start_at: {name: file_name},
            count: count,
            prefix: file_name) do |file|
          f = new(bucket.account, bucket: bucket, attrs: file)

          if f.name == file_name
            if block_given?
              yield f
            else
              files << f
            end
          end
        end
        files
      end

    end
  end
end
