module Backblaze::B2

  ##
  # A class to represent the online buckets. Mostly used for file access
  class Bucket < Base
    ##
    # Creates a bucket from all of the possible parameters. This should be rarely used and instead use a finder or creator
    # @param [#to_s] bucket_name the bucket name
    # @param [#to_s] bucket_id the bucket id
    # @param [#to_s] bucket_type the bucket publicity type
    # @param [#to_s] account_id the account to which this bucket belongs
    def initialize(bucket_name:, bucket_id:, bucket_type:, account_id:, **_)
      @bucket_name = bucket_name
      @bucket_id = bucket_id
      @bucket_type = bucket_type
      @account_id = account_id
    end

    # @return [String] bucket name
    attr_reader :bucket_name
    alias_method :name, :bucket_name

    # @return [String] bucket id
    attr_reader :bucket_id
    alias_method :id, :bucket_id

    # @return [String] account id
    attr_reader :account_id

    # @return [String] bucket type
    attr_reader :bucket_type

    # @return [Boolean] is the bucket public
    def public?
      @bucket_type == 'allPublic'
    end

    # @return [Boolean] is the bucket private
    def private?
      !public?
    end

    # Check if equivalent. Takes advantage of globally unique names
    # @return [Boolean] equality
    def ==(other)
      bucket_name == other.bucket_name
    end

    ##
    # Lists all files in the bucket.
    # @param [Integer] limit max number of files to retrieve. Set to `-1` to get all files.
    # @param [Boolean] cache if there is no cache, create one. If there is a cache, use it.
    # @param [String, nil] prefix only return files whose names start with this prefix
    # @param [String, nil] delimiter used to group files into virtual folders (typically "/")
    # @return [Array<Backblaze::B2::File>]
    def files(limit: 100, cache: false, prefix: nil, delimiter: nil)
      if cache && !@file_name_cache.nil?
        if limit <= @file_name_cache[:limit]
          return @file_name_cache[:files]
        end
      end

      raw_files = file_list(bucket_id: bucket_id, limit: limit, retrieved: 0, first_file: nil, start_field: 'startFileName', prefix: prefix, delimiter: delimiter)

      files = raw_files.map do |f|
        Backblaze::B2::File.new(**f.merge(bucket_id: bucket_id, bucket_name: bucket_name))
      end
      if cache
        @file_name_cache = {limit: limit, files: files}
      end
      files
    end

    # @deprecated Use {#files} instead
    def file_names(limit: 100, cache: false, convert: true, double_check_server: false)
      if convert
        files(limit: limit, cache: cache)
      else
        file_list(bucket_id: bucket_id, limit: limit, retrieved: (double_check_server ? 0 : -1), first_file: nil, start_field: 'startFileName')
      end
    end

    ##
    # Lists all file versions in the bucket, grouped by file name.
    # @param [Integer] limit max number of versions to retrieve. Set to `-1` to get all.
    # @param [Boolean] cache use cached results if available
    # @return [Array<Backblaze::B2::File>]
    def file_versions(limit: 100, cache: false, convert: true, double_check_server: false)
      if cache && !@file_versions_cache.nil?
        if limit <= @file_versions_cache[:limit]
          return @file_versions_cache[:files]
        end
      end
      versions = super(limit: limit, double_check_server: double_check_server, bucket_id: bucket_id)
      files = versions.group_by(&:file_name).map do |name, vers|
        File.new(file_name: name, bucket_id: bucket_id, bucket_name: bucket_name, versions: vers)
      end
      if cache
        @file_versions_cache = {limit: limit, files: files}
      end
      files
    end

    # Delete this bucket. The bucket must be empty.
    # @raise [Backblaze::BucketError] if the bucket cannot be deleted
    # @return [void]
    def destroy!
      response = post('/b2_delete_bucket', body: {
        accountId: @account_id,
        bucketId: bucket_id
      }.to_json)
      raise Backblaze::BucketError.new(response) unless response.code / 100 == 2
      @destroyed = true
    end

    # @return [Boolean] whether this bucket has been destroyed locally
    def destroyed?
      !!@destroyed
    end

    # @deprecated Use {#destroyed?} instead
    def exists?
      !destroyed?
    end

    # Update this bucket's type
    # @param [Symbol] type :public or :private
    # @raise [Backblaze::BucketError] if the bucket cannot be updated
    # @return [self]
    def update(type:)
      response = post('/b2_update_bucket', body: {
        accountId: @account_id,
        bucketId: bucket_id,
        bucketType: (type == :public ? 'allPublic' : 'allPrivate')
      }.to_json)
      raise Backblaze::BucketError.new(response) unless response.code / 100 == 2
      @bucket_type = response['bucketType']
      self
    end

    def upload_url
      self.class.upload_url(bucket_id: bucket_id)
    end

    # Generate a download authorization token for files in this bucket.
    # @param [String] file_name_prefix only authorize downloads of files starting with this prefix
    # @param [Integer] valid_duration_in_seconds how long the token is valid (1 to 604800)
    # @return [String] the authorization token
    def download_authorization(file_name_prefix: '', valid_duration_in_seconds: 86400)
      response = post('/b2_get_download_authorization', body: {
        bucketId: bucket_id,
        fileNamePrefix: file_name_prefix,
        validDurationInSeconds: valid_duration_in_seconds
      }.to_json)
      raise Backblaze::BucketError.new(response) unless response.code == 200
      response['authorizationToken']
    end

    class << self
      ##
      # Create a bucket
      # @param [String] name name of the new bucket
      #   must be no more than 50 characters and only contain letters, digits, "-", and "_".
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

        raise Backblaze::BucketError.new(response) unless response.code / 100 == 2

        new(**response_to_hash(response))
      end

      def upload_url(bucket_id:)
        response = post('/b2_get_upload_url', body: {bucketId: bucket_id}.to_json)
        raise Backblaze::BucketError.new(response) unless response.code / 100 == 2
        {url: response['uploadUrl'], token: response['authorizationToken']}
      end

      ##
      # Find a bucket by name
      # @param [String] name the bucket name to find
      # @return [Backblaze::B2::Bucket, nil] the bucket or nil if not found
      def find(name:)
        buckets.find { |b| b.name == name }
      end

      ##
      # List buckets for account
      # @return [Array<Backblaze::B2::Bucket>] buckets for this account
      def buckets
        body = {
          accountId: Backblaze::B2.account_id
        }
        response = post('/b2_list_buckets', body: body.to_json)
        response['buckets'].map do |bucket|
          new(**response_to_hash(bucket))
        end
      end
    end
  end
end
