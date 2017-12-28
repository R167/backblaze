require 'backblaze/b2/base'
require 'backblaze/b2/bucket'
require 'backblaze/b2/file'
require 'backblaze/b2/file_version'
require 'tempfile'
require 'digest/sha1'
require 'base64'

module Backblaze::B2
  class << self
    attr_reader :account_id, :token, :api_url, :download_url, :api_path

    ##
    # Authenticates with the server to get the authorization data. Raises an error if there is a problem
    #
    # @param [#to_s] account_id the account id
    # @param [#to_s] application_key the private app key
    # @raise [Backblaze::AuthError] when unable to authenticate
    # @return [void]
    def login(options)
      api_path = options.fetch(:api_path) { '/b2api/v1/' }

      params = {
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Authorization' => bearer(options)
        }
      }
      api_path = "/#{api_path}/".gsub(/\/+/, '/')

      response = HTTParty.get("https://api.backblazeb2.com#{api_path}b2_authorize_account", params)

      raise Backblaze::AuthError, response unless response.success?

      @account_id = response['accountId']
      @token = response['authorizationToken']
      @api_url = response['apiUrl']
      @download_url = response['downloadUrl']
      @api_path = api_path
      Backblaze::B2::Base.base_uri("#{@api_url}#{api_path}")
      Backblaze::B2::Base.headers('Authorization' => token,
                                  'Content-Type' => 'application/json')
    end

    def bearer(options)
      account_id = options.fetch(:account_id)
      application_key = options.fetch(:application_key)
      token = Base64.strict_encode64("#{account_id}:#{application_key}")

      "Basic #{token}"
    end
  end
end
