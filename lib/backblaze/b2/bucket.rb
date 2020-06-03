# frozen_string_literal: true

require "set"

module Backblaze::B2
  class Bucket < Base
    NAME_KEY = "bucketName"
    ID_KEY = "bucketId"

    ATTRIBUTES = Set.new(%w[bucketId bucketName bucketInfo bucketType corsRules lifecycleRules revision options]).freeze

    def initialize(account, properties = {})
      super
    end

    class << self
      ##
      # Call the api to get all buckets in the account
      # @param [Account] account Account to search for buckets in
      # @return [Array<Bucket>] all buckets in the account
      def all(account)
        account.api.list_buckets["buckets"].map do |bucket|
          Bucket.new(account, bucket)
        end
      end
    end

    def refresh!
      properties = account.without_fetch { account.api.list_buckets(bucket_id: id, bucket_name: name)["buckets"].first }
      set_properties(properties)
    end

    def name
      self["bucketName"]
    end
    alias bucket_name name

    def id
      self["bucketId"]
    end
    alias bucket_id id

    def type
      self["bucketType"]
    end
    alias bucket_type type

    def info
      self["bucketInfo"]
    end
    alias bucket_info info

    def cors_rules
      self["corsRules"]
    end

    def lifecycle_rules
      self["lifecycleRules"]
    end

    def valid_attributes
      ATTRIBUTES
    end

    ##
    # Check if two buckets refer to the same Backblaze object
    # @return [Boolean] if buckets refer to same object
    def ==(other)
      other.class == self.class && id == other.id && name == other.name
    end

    ##
    # Get an upload url and authorization
    # @return [Hash] :auth, :url, and :bucket_id
    def upload_url
      upload = account.api.get_upload_url(id)
      {
        auth: upload["authorizationToken"],
        url: upload["uploadUrl"],
        bucket_id: upload["bucketId"]
      }
    end

    ##
    # Lists out files in the bucket
    #
    # List out files in a bucket. This operation performs the lookup in batches. When no block is passed, an array
    # of all fetched files is returned. When passed a block, each file is yielded to it.
    #
    # @example Print the name of all files in the bucket
    #   bucket = Backblaze::B2.buckets.first
    #   bucket.find_files(count: :all) do |file|
    #     puts file.file_name
    #   end
    #
    # @param start_at first file to start searching for, esp. for resuming a search.
    # @param [Integer, :all, :none] limit stop after fetching this many files. When passed a positive value, this is the case.
    #   If you want no limit on the results returned, use the special value `:all` or `:none`. This will set limit to infinity.
    # @param batch_size Number of results to fetch per api call. Defaults to the transaction max. If you are performing
    #   work where you need files fetched very quickly, consider reducing.
    # @param prefix Only files with this prefix in the bucket will be returned
    # @param delimiter Split files and folders on this character. (see Api#list_file_names)
    # @yield OPTIONAL: When included, used to process each file
    # @yieldparam [FileVersion] file Each found file
    # @return [ListResult<FileVersion>, ListResult] List of all the files found within our bounds
    def find_files(limit:, start_at: nil, batch_size: 1000, prefix: nil, delimiter: nil)
      files = []

      account.api.list_generic(:list_file_names, id,
        start_at: {name: start_at},
        count: limit,
        prefix: prefix,
        delimiter: delimiter,
        batch_size: batch_size) do |file|
        f = FileVersion.new(account, bucket: self, attrs: file)
        if block_given?
          yield f
        else
          files << f
        end
      end.tap { |r| r.results = files unless block_given? }
    end

    ##
    # Find all file versions. Similar to {#find_files}, except this returns any file version
    # @param (see #find_files)
    # @yield (see #find_files)
    # @yieldparam (see #fine_files)
    # @see #find_files
    # @see https://www.backblaze.com/b2/docs/file_versions.html B2 File Versions
    def find_file_versions(limit:, start_at: nil, batch_size: 1000, prefix: nil, delimiter: nil)
      files = []

      account.api.list_generic(:list_file_versions, id,
        start_at: start_at,
        count: limit,
        prefix: prefix,
        delimiter: delimiter,
        batch_size: batch_size) do |file|
        f = FileVersion.new(account, bucket: self, attrs: file)
        if block_given?
          yield f
        else
          files << f
        end
      end.tap { |r| r.results = files unless block_given? }
    end

    ##
    # Find all versions of a specific file.
    #
    # Refer to {#find_files} for more information on how to use the block parameters
    #
    # @param limit Max number of results returned. Since we looking at one file here, this defaults to call. Refer to
    #   {.find_files} for what that means
    # @return (see .find_file_versions)
    def find_versions_of_file(file_name:, limit: :all)
      files = []

      account.api.list_generic(:list_file_versions, id,
        start_at: {name: file_name},
        count: limit,
        prefix: file_name) do |file|
        f = FileVersion.new(account, bucket: self, attrs: file)

        if f.name == file_name
          if block_given?
            yield f
          else
            files << f
          end
        end
      end.tap { |r| r.results = files unless block_given? }
    end
  end
end
