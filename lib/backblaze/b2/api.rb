# frozen_string_literal: true

require 'http'
require 'multi_json'

require 'backblaze/version'

module Backblaze::B2
  ##
  # Minimal wrapper around the b2 api to handle basic things like connections,
  # urls, etc.
  class Api
    API_VERSION = "v2"
    AUTH_ENDPOINT = "https://api.backblazeb2.com/b2api/#{API_VERSION}/b2_authorize_account"

    # User agent for all requests in this gem. This follows backblaze's user agent recommendations
    # listed on their [integration checklist](https://www.backblaze.com/b2/docs/integration_checklist.html)
    USER_AGENT = "backblaze-rb/#{Backblaze::VERSION}+#{RUBY_ENGINE}/#{RUBY_VERSION}"

    attr_reader :api_url, :download_url, :account_id

    def initialize(app_key_id, app_key_secret)
      @app_key_id = app_key_id
      @connection_key = "b2-#{@app_key_id}"
      @app_key_secret = app_key_secret
      @auth_token = nil
    end

    ##
    # Perform all nested HTTP api requests over the same connection using HTTP Keep-Alive
    def with_persistent_connection
      if connection_info[:count] == 0
        connection_info[:conn] = connection.persistent(api_url)
      end
      connection_info[:count] += 1
      yield
    ensure
      connection_info[:count] -= 1
    end

    def connection
      if keep_alive?
        connection_info[:conn]
      else
        HTTP[accept: "application/json"].auth(auth_token)
      end
    end

    ##
    # Helper for getting access to the auth token needed by nearly all requests
    # @param refresh force a reauthorization of credentials
    # @return an auth_token
    def auth_token(refresh = false)
      authorize_account if refresh || !@auth_token
      @auth_token
    end

    ##
    # Get an account authorization
    # @return [Hash] account attributes
    # @see https://www.backblaze.com/b2/docs/b2_authorize_account.html
    def authorize_account
      response = HTTP.basic_auth(user: @app_key_id, pass: @app_key_secret).get(AUTH_ENDPOINT)

      if response.status.ok?
        data = parse(response)
        @download_url = data['downloadUrl']
        @api_url = data['apiUrl']
        @auth_token = data['authorizationToken']

        data
      else
        # TODO: Error handling
        raise
      end
    end

    ##
    # Cancel an in progress large file upload
    # @see https://www.backblaze.com/b2/docs/b2_cancel_large_file.html
    def cancel_large_file(file_id)
      post_api('b2_cancel_large_file', fileId: file_id)
    end

    ##
    # Create a bucket for the current account with the given attributes
    # @param name Bucket name
    # @param public: Bucket public/private visability
    # @param info: Additional bucket meta data. This is where you can specify
    #   bucket wide `Cache-Control` options
    # @param cors: list of cors rules
    # @param lifecycle: list of lifecyle rules
    # @return [Hash] bucket creation attributes
    # @see https://www.backblaze.com/b2/docs/lifecycle_rules.html Lifecycle Rules
    # @see https://www.backblaze.com/b2/docs/cors_rules.html CORS Rules
    # @see https://www.backblaze.com/b2/docs/b2_create_bucket.html
    def create_bucket(name, public: false, info: {}, cors: [], lifecycle: [])
      request_attributes = {
        accountId: account_id,
        bucketName: name,
        bucketType: (public ? 'allPublic' : 'allPrivate'),
        bucketInfo: info,
        corsRules: cors,
        lifecycleRules: lifecycle
      }
      post_api('b2_create_bucket', request_attributes)
    end

    def create_key(name, capabilities, expires_in: nil, bucket_id: nil, prefix: nil)
      request_attributes = {
        accountId: account_id,
        keyName: name,
        capabilities: capabilities,
        validDurationInSeconds: expires_in.to_i,
        bucketId: bucket_id,
        namePrefix: prefix
      }
      post_api('b2_create_key', request_attributes)
    end

    def delete_bucket(bucket_id)
      post_api('b2_delete_bucket', accountId: account_id, bucketId: bucket_id)
    end

    def delete_file_version(name, file_id)
      post_api('b2_delete_file_version', fileName: name, fileId: file_id)
    end

    def delete_key(key_id)
      post_api('b2_delete_key', applicationKeyId: key_id)
    end

    ##
    # Finalize uploading a large file
    # @param file_id the file id returned in {#start_large_file}
    # @param [Array<String>] sha1_array list of sha1 for each of the upload parts in order
    # @return large file info
    # @see https://www.backblaze.com/b2/docs/b2_finish_large_file.html
    def finish_large_file(file_id, sha1_array)
      post_api('b2_finish_large_file', fileId: file_id, partSha1Array: sha1_array)
    end

    def get_file_info(file_id)
      post_api('b2_get_file_info', fileId: file_id)
    end


    def start_large_file

    end

    private

    ##
    # Generate the api url for the given endpoint. This takes into account if we
    # need the fully qualified url, or just the path (i.e. are we using a persistent connection)
    # @param endpoint b2 api action
    # @return url to pass to connection
    def build_api_url(endpoint)
      "#{api_url if keep_alive?}/b2api/#{API_VERSION}/#{endpoint}"
    end

    ##
    # Make a post request to the api endpoint.
    def post_api(endpoint, body={})
      body = json_dump(body) unless body.is_a?(String)
      path = build_api_url(endpoint)
      response = connection.post(endpoint, body: body)
      parse(response)
    end

    def connection_info
      Thread.current[@connection_key] ||= {count: 0, conn: nil}
    end

    ##
    # Whether or not we are currently nested inside a persistent conneciton
    def keep_alive?
      connection_info[:count] > 0
    end

    ##
    # Parse the body as JSON
    def parse(body, symbolize = false)
      MultiJson.load(body.to_s, symbolize_keys: symbolize)
    end

    def json_dump(data)
      MultiJson.json_dump(data)
    end

  end
end
