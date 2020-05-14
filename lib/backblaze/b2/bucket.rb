# frozen_string_literal: true

module Backblaze::B2
  class Bucket < Base
    include Resource

    ATTRIBUTES = %w{accountId bucketId bucketInfo bucketName bucketType corsRules lifecycleRules options revision}.freeze
    create_attributes ATTRIBUTES

    alias_method :name, :bucket_name
    alias_method :id, :bucket_id

    class << self
      ##
      # Call the api to get all buckets in the account
      # @param [Account] account Account to search for buckets in
      # @return [Array<Bucket>] all buckets in the account
      def all(account)
        account.api.list_buckets['buckets'].map do |bucket|
          Bucket.from_api(account, bucket)
        end
      end

      ##
      # Create a minimal version of a bucket comprised of the name and id.
      #
      # Some operations in the B2 api require just the bucket_id while others require the name. It is best practice
      # to make sure you always instantiate new objects with at least these two fields (when you've been keeping them
      # in storage, e.g. saved in redis), otherwise you may end up with **way** more api requets than you expect your
      # application should be making.
      # @return [Bucket]
      def from_storage(name:, id:, account: nil)
        Bucket.new(account, attrs: {bucket_name: name, bucket_id: id})
      end

      ##
      # Try a variety of techniques to coerce an object into a bucket
      #
      # @param [Bucket, Hash, String<:bucket_id>] obj
      # @param [Account] account acount this bucket is associated with
      # @return [Bucket]
      # @raise [KeyError] when the object is a Hash, but doesn't have the proper keys
      def coerce(obj, account = nil)
        if obj.is_a?(Bucket)
          obj
        elsif obj.is_a?(Hash)
          if obj.include?(:bucket_name) || obj.include?('bucketName')
            Bucket.from_api(account, attrs: obj)
          elsif obj.include?(:name) && obj.include?(:id)
            Bucket.from_storage(account: account, **obj)
          else
            raise KeyError, "Hash must have name/id keys"
          end
        else
          new(account, attrs: {bucket_id: bucket})
        end
      end
    end

    ##
    # Search the bucket for all visible files
    #
    # Warning: This will make a lot of API calls. Be careful about calling it. It is generally better to use the methods
    # such as {FileVersion.find_files} and {FileVersion.find_file_versions} as these give you more fine-grained control
    # over what and how much data you are fetching.
    # @param count (see FileVersion.find_files)
    # @yield Each file in the bucket
    # @yieldparam [FileVersion] file the current file
    # @return [Hash] information about the last iteration
    def all_files!(count: :all, &block)
      FileVersion.find_files(bucket: self, count: count, &block)
    end

    ##
    # Get an upload url and authorization
    # @return [Hash] :auth, :url, and :bucket_id
    def upload_url
      upload = account.api.get_upload_url
      {
        auth: upload['authorizationToken'],
        url: upload['uploadUrl'],
        bucket_id: upload['bucketId']
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
    # @param [Integer, :all] count Stop after fetching this many files. When passed a positive value, this is the case.
    #   If you want no limit on the results returned, use the special value `:all`. This will set count to infinity.
    # @param batch_size Number of results to fetch per api call. Defaults to the transaction max. If you are performing
    #   work where you need files fetched very quickly, consider reducing.
    # @param prefix Only files with this prefix in the bucket will be returned
    # @param delimiter Split files and folders on this character. (see Api#list_file_names)
    # @yield OPTIONAL: When included, used to process each file
    # @yieldparam [FileVersion] file Each found file
    # @return [ListResult<FileVersion>, ListResult] List of all the files found within our bounds
    def find_files(count:, start_at: nil, batch_size: 1000, prefix: nil, delimiter: nil)
      files = []

      self.class.api_list(account, :list_file_names, self.id,
          start_at: {name: start_at},
          count: count,
          prefix: prefix,
          delimiter: delimiter) do |file|
        f = FileVersion.new(account, bucket: self, attrs: file)
        if block_given?
          yield f
        else
          files << f
        end
      end.tap{ |r| r.results = files unless block_given?}
    end

    ##
    # Find all file versions. Similar to {#find_files}, except this returns any file version
    # @param (see #find_files)
    # @yield (see #find_files)
    # @yieldparam (see #fine_files)
    # @see #find_files
    # @see https://www.backblaze.com/b2/docs/file_versions.html B2 File Versions
    def find_file_versions(bucket:, count:, start_at: nil, batch_size: 1000, prefix: nil, delimiter: nil)
      files = []

      self.class.api_list(bucket.account, :list_file_versions, bucket.id,
          start_at: start_at,
          count: count,
          prefix: prefix,
          delimiter: delimiter) do |file|
        f = FileVersion.new(bucket.account, bucket: bucket, attrs: file)
        if block_given?
          yield f
        else
          files << f
        end
      end.tap{ |r| r.results = files unless block_given?}
    end

    ##
    # Find all versions of a specific file.
    #
    # Refer to {#find_files} for more information on how to use the block parameters
    #
    # @param bucket (see .find_files)
    # @param file_name Name of the file to search for
    # @param count Max number of results returned. Since we looking at one file here, this defaults to call. Refer to
    #   {.find_files} for what that means
    # @return (see .find_file_versions)
    def find_versions_of_file(file_name:, count: :all)
      files = []

      self.class.api_list(bucket.account, :list_file_versions, bucket.id,
          start_at: {name: file_name},
          count: count,
          prefix: file_name) do |file|
        f = FileVersion.new(bucket.account, bucket: bucket, attrs: file)

        if f.name == file_name
          if block_given?
            yield f
          else
            files << f
          end
        end
      end.tap{ |r| r.results = files unless block_given?}
    end

  end
end
