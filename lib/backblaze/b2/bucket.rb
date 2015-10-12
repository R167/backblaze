module Backblaze::B2
  class Bucket < Base

    ##
    # Creates a bucket from all of the possible parameters. This sould be rarely used and instead use a finder or creator
    # @param [#to_s] :bucket_name the bucket name
    # @param [#to_s] :bucket_id the bucket id
    # @param [#to_s] :bucket_type the bucket publicity type
    # @param [#to_s] :account_id the account to which this bucket belongs
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

    # @return [true, false] is the bucket public
    def public?
      @bucket_type == 'allPublic'
    end

    # @return [true, false] is the bucket private
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

    def files(first_file: nil, limit: 100, convert: true, retreived: 0)
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
      if convert
        files.map! do |f|
          params = f.map {|k, v| [underscore(k).to_sym, v]}.to_h
          Backblaze::B2::File.new(params)
        end
      end

      retreived = retreived + files.size

      if (limit > retreived || limit == -1) && !response['nextFileName'].nil?
        limit = limit - files.size if limit > retreived
        files.concat self.files(
          first_file: response['nextFileName'],
          limit: limit,
          convert: convert,
          retreived: retreived
        )
      else
        files
      end
    end

    class << self
      ##
      # Create a bucket
      # @param [String] :name name of the new bucket
      #   must be no more than 50 character and only contain letters, digits, "-", and "_".
      #   must be globally unique
      # @param [:public, :private] :type determines the type of bucket
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
