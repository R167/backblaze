module Backblaze::B2
  ##
  # A class to represent the online buckets. Mostly used for file access
  class Bucket < Base
    ##
    # Creates a bucket from all of the possible parameters. This sould be rarely used and instead use a finder or creator
    # @param [#to_s] bucket_name the bucket name
    # @param [#to_s] bucket_id the bucket id
    # @param [#to_s] bucket_type the bucket publicity type
    # @param [#to_s] account_id the account to which this bucket belongs
    def initialize(options)
      @bucket_name = options.fetch(:bucket_name)
      @bucket_id = options.fetch(:bucket_id)
      @bucket_type = options.fetch(:bucket_type)
      @account_id = options.fetch(:account_id)
    end

    # @return [String] bucket name
    attr_reader :bucket_name

    alias name bucket_name

    # @return [String] bucket id
    attr_reader :bucket_id

    # @return [Boolean] is the bucket public
    def public?
      @bucket_type == 'allPublic'
    end

    # @return [Boolean] is the bucket private
    def private?
      !public?
    end

    # @return [String] account id
    attr_reader :account_id

    # @return [String] bucket type
    attr_reader :bucket_type

    # Check if eqivalent. Takes advantage of globally unique names
    # @return [Boolean] equality
    def ==(other)
      bucket_name == other.bucket_name
    end

    ##
    # Lists all files that are in the bucket. This is the basic building block for the search.
    # @param [String] first_file first file in the bucket to start listing from
    # @param [Integer] limit max number of files to retreive. Set to `-1` to get all files.
    #   This is not exact as it mainly just throws the limit into max param on the request
    #   so it will try to grab at least `limit` files, unless there aren't enoungh in the bucket
    # @param [Boolean] cache if there is no cache, create one. If there is a cache, use it.
    #   Will check if the previous cache had the same size limit and convert options
    # @param [Boolean] convert convert the files to Backblaze::B2::File objects
    # @param [Integer] double_check_server whether or not to assume the server returns the most files possible
    # @return [Array<Backblaze::B2::File>] when convert is true
    # @return [Array<Hash>] when convert is false
    # @note many of these methods are for the recusion
    def file_names(first_file: nil, limit: 100, cache: false, convert: true, double_check_server: false)
      if cache && !@file_name_cache.nil?
        if limit <= @file_name_cache[:limit] && convert == @file_name_cache[:convert]
          return @file_name_cache[:files]
        end
      end

      retreive_count = (double_check_server ? 0 : -1)
      files = file_list(bucket_id: bucket_id, limit: limit, retreived: retreive_count, first_file: first_file, start_field: 'startFileName'.freeze)

      merge_params = { bucket_id: bucket_id }
      if convert
        files.map! do |f|
          Backblaze::B2::File.new(f.merge(merge_params))
        end
      end
      if cache
        @file_name_cache = { limit: limit, convert: convert, files: files }
      end
      files
    end

    def file_versions(limit: 100, cache: false, convert: true, double_check_server: false)
      if cache && !@file_versions_cache.nil?
        if limit <= @file_versions_cache[:limit] && convert == @file_versions_cache[:convert]
          return @file_versions_cache[:files]
        end
      end
      file_versions = super(limit: 100, convert: convert, double_check_server: double_check_server, bucket_id: bucket_id)
      files = file_versions.group_by { |version| convert ? version.file_name : version[:file_name] }
      if convert
        files = files.map do |name, versions|
          File.new(file_name: name, bucket_id: bucket_id, versions: versions)
        end
      end
      @file_versions_cache = if cache
                               { limit: limit, convert: convert, files: files }
                             else
                               {}
                             end
      files
    end

    def upload_url
      self.class.upload_url(bucket_id: bucket_id)
    end

    class << self
      ##
      # Create a bucket
      # @param [String] name name of the new bucket
      #   must be no more than 50 character and only contain letters, digits, "-", and "_".
      #   must be globally unique
      # @param [:public, :private] type determines the type of bucket
      # @raise [Backblaze::BucketError] unable to create the specified bucket
      def create(name:, type:)
        body = {
          accountId: Backblaze::B2.account_id,
          bucketName: name,
          bucketType: (type == :public ? 'allPublic' : 'allPrivate')
        }
        response = post('/b2_create_bucket', body: body.to_json)

        raise Backblaze::BucketError, response unless response.code / 100 == 2

        params = Hash[response.map { |k, v| [Backblaze::Utils.underscore(k).to_sym, v] }]

        new(params)
      end

      def upload_url(bucket_id:)
        response = post('/b2_get_upload_url', body: { bucketId: bucket_id }.to_json)
        raise Backblaze::BucketError, response unless response.code / 100 == 2
        { url: response['uploadUrl'], token: response['authorizationToken'] }
      end

      ##
      # List buckets for account
      # @return [Array<Backblaze::Bucket>] buckets for this account
      def buckets
        body = {
          accountId: Backblaze::B2.account_id
        }
        response = post('/b2_list_buckets', body: body.to_json)
        response['buckets'].map do |bucket|
          params = Hash[bucket.map { |k, v| [Backblaze::Utils.underscore(k).to_sym, v] }]
          new(params)
        end
      end

      def get_bucket(name:)
        buckets.find { |b| b.bucket_name == name }
      end
    end
  end
end
