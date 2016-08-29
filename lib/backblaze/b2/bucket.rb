module Backblaze::B2

  ##
  # A class to represent the online buckets. Mostly used for file access
  class Bucket < Base

    MAX_DURATION = 60 * 60 * 24 * 7 # One week

    ##
    # Creates a bucket from all of the possible parameters. This sould be rarely used and instead use a finder or creator
    # @param [#to_s] bucket_name the bucket name
    # @param [#to_s] bucket_id the bucket id
    # @param [#to_s] bucket_type the bucket publicity type
    # @param [#to_s] account_id the account to which this bucket belongs
    def initialize(bucket_name:, bucket_id:, bucket_type:, account_id:, cache: false)
      @bucket_name = bucket_name
      @bucket_id = bucket_id
      @bucket_type = bucket_type
      @account_id = account_id
    end

    # @return [String] bucket name
    def bucket_name
      @bucket_name
    end

    # @return [String] bucket id
    def bucket_id
      @bucket_id
    end

    # @return [Boolean] is the bucket public
    def public?
      @bucket_type == 'allPublic'
    end

    # @return [Boolean] is the bucket private
    def private?
      !public?
    end

    # @return [String] account id
    def account_id
      @account_id
    end

    # @return [String] bucket type
    def bucket_type
      @bucket_type
    end

    # Check if eqivalent. Takes advantage of globally unique names
    # @return [Boolean] equality
    def ==(other)
      bucket_name == other.bucket_name
    end

    ##
    # Retreive an authorizationToken for the specific path. Really only useful for
    # private buckets.
    # @param [String] prefix the prefix for files the authorization token will allow b2_download_file_by_name to access
    # @param [Integer] duration The number of seconds before the authorization token will expire.
    #   The maximum value that this can be is 604800, which is one week in seconds.
    # @return [String] the authorization token
    def download_authorization(prefix:, duration:)
      body = {
        prefix: prefix,
        fileNamePrefix: bucket_id,
        validDurationInSeconds: Backblaze::B2::Utils.limit(duration, 1..MAX_DURATION).to_i
      }
      response = post('/b2_get_download_authorization', body: body.to_json)
      raise Backblaze::BucketError.new(response) unless response.code / 100 == 2
      response['authorizationToken']
    end

    ##
    # Lists all files that are in the bucket. This is the basic building block for the search.
    # @param [Integer] limit max number of files to retreive. Set to `-1` to get all files.
    #   This is not exact as it mainly just throws the limit into max param on the request
    #   so it will try to grab at least `limit` files, unless there aren't enoungh in the bucket
    # @param [Boolean] cache if there is no cache, create one. If there is a cache, use it.
    #   Will check if the previous cache had the same size limit and convert options
    # @param [Boolean] convert convert the files to Backblaze::B2::FileObject objects
    # @param [Integer] double_check_server whether or not to assume the server returns the most files possible
    # @param [Integer] expires_in seconds until the the cache expires
    # @return [Array<Backblaze::B2::FileObject>] when convert is true
    # @return [Array<Hash>] when convert is false
    # @note many of these methods are for the recusion
    def file_names(limit: 100, cache: false, convert: true, double_check_server: false, expires_in: 3600)
      if cache && !@file_name_cache.nil?
        if @file_name_cache[:expiration] < Time.now
          if limit <= @file_name_cache[:limit] && convert == @file_name_cache[:convert]
            return @file_name_cache[:files]
          end
        else
          @file_name_cache = nil
        end
      end

      retreive_count = (double_check_server ? 0 : -1)
      files = file_list(bucket_id: bucket_id, limit: limit, retreived: retreive_count, first_file: nil, start_field: 'startFileName'.freeze)

      merge_params = {bucket_id: bucket_id}
      files.map! do |f|
        Backblaze::B2::FileObject.new(f.merge(merge_params))
      end if convert
      if cache
        @file_name_cache = {limit: limit, convert: convert, files: files, expiration: Time.now + expires_in}
      end
      files
    end

    ##
    # Lists all file versions that are in the bucket. This is nearly identical to
    # `#file_names`, except this will group all file_versions into their respective file
    # @see file_names
    def file_versions(limit: 100, cache: false, convert: true, double_check_server: false, expires_in: 3600)
      if cache && !@file_versions_cache.nil?
        if @file_versions_cache[:expiration] < Time.now
          if limit <= @file_versions_cache[:limit] && convert == @file_versions_cache[:convert]
            return @file_versions_cache[:files]
          end
        else
          @file_versions_cache = nil
        end
      end
      file_versions = super(limit: limit, convert: convert, double_check_server: double_check_server, bucket_id: bucket_id)
      files = file_versions.group_by {|version| convert ? version.file_name : version[:file_name]}
      if convert
        files = files.map do |name, versions|
          FileObject.new(file_name: name, bucket_id: bucket_id, versions: versions)
        end
      end
      if cache
        @file_versions_cache = {limit: limit, convert: convert, files: files, expiration: Time.now + expires_in}
      end
      files
    end

    ##
    # A way to manually force cache expiration
    def pop_cache!
      @file_versions_cache = nil
      @file_name_cache = nil
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

        raise Backblaze::BucketError.new(response) unless response.code / 100 == 2

        params = Hash[response.map{|k,v| [Backblaze::Utils.underscore(k).to_sym, v]}]

        new(params)
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
          params = Hash[bucket.map{|k,v| [Backblaze::Utils.underscore(k).to_sym, v]}]
          new(params)
        end
      end
    end
  end
end
