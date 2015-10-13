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
    def initialize(bucket_name:, bucket_id:, bucket_type:, account_id:)
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
    # Lists all files that are in the bucket. This is the basic building block for the search.
    # @param [Integer] limit max number of files to retreive. Set to `-1` to get all files.
    #   This is not exact as it mainly just throws the limit into max param on the request
    #   so it will try to grab at least `limit` files, unless there aren't enoungh in the bucket
    # @param [Boolean] cache if there is no cache, create one. If there is a cache, use it.
    #   Will check if the previous cache had the same size limit and convert options
    # @param [Boolean] convert convert the files to Backblaze::B2::File objects
    # @param [Integer] retreived number of files used for aggresive recursion.
    #   When `retreived >= 0`, this will be used to assure that the response did indeed return
    #   the max number of entries. This is mainly just used for testing purposes, so you should
    #   usually just leave it as is. It is honestly just a check that really doesn't need to
    #   be performed. Primarily for large limits
    # @param [String] first_file the first file name to search for
    # @return [Array<Backblaze::B2::File>] when convert is true
    # @return [Array<Hash>] when convert is false
    # @note many of these methods are for the recusion
    def files(limit: 100, cache: false, convert: true, retreived: -1, first_file: nil)
      if cache && !@file_cache.nil?
        if limit <= @file_cache[:limit] && convert == @file_cache[:convert]
          return @file_cache[:files]
        end
      end
      params = {'bucketId' => bucket_id}
      if limit == -1
        params['maxFileCount'] = 1000
      elsif limit > 1000
        params['maxFileCount'] = 1000
      elsif limit > 0
        params['maxFileCount'] = limit
      else
        return []
      end
      params['startFileName'] = first_file unless first_file.nil?

      response = post('/b2_list_file_names', body: params.to_json)

      files = response['files']
      files.map! do |f|
        params = f.map {|k, v| [underscore(k).to_sym, v]}.to_h
        if convert
          Backblaze::B2::File.new(params)
        else
          params
        end
      end

      original_limit = limit if cache

      retreived = retreived + files.size if retreived >= 0
      if limit > 0
        limit = limit - (retreived >= 0 ? files.size : 1000)
        limit = 0 if limit < 0
      end

      if (limit > 0 || limit == -1) && !response['nextFileName'].nil?
        files.concat self.files(
          first_file: response['nextFileName'],
          limit: limit,
          convert: convert,
          retreived: retreived
        )
      else
        if cache
          @file_cache = {limit: original_limit, convert: convert, files: files}
        end
        files
      end
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

        params = %w(account_id bucket_id bucket_name bucket_type).map {|e| [e.to_sym, response[camelize(e)]]}.to_h

        new(params)
      end

    end
  end
end
