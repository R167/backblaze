require "backblaze/b2/base"
require "backblaze/b2/bucket"
require "backblaze/b2/file"
require "backblaze/b2/file_version"
require 'net/http'
require 'tempfile'
require 'digest/sha1'

module Backblaze::B2
  class << self
    attr_reader :account_id, :token, :api_url, :download_url, :api_path,
                :recommended_part_size, :absolute_minimum_part_size, :allowed

    ##
    # Authenticates with the server to get the authorization data.
    #
    # @param [#to_s] account_id the account id
    # @param [#to_s] application_key the private app key
    # @param [String] api_path the API version path (defaults to v2)
    # @raise [Backblaze::AuthError] when unable to authenticate
    # @return [void]
    def login(account_id:, application_key:, api_path: '/b2api/v2/')
      @credentials = {account_id: account_id, application_key: application_key, api_path: api_path}

      options = {
        basic_auth: {username: account_id, password: application_key}
      }
      api_path = "/#{api_path}/".gsub(/\/+/, '/')
      response = HTTParty.get("https://api.backblazeb2.com#{api_path}b2_authorize_account", options)
      raise Backblaze::AuthError.new(response) unless response.code == 200

      @account_id = response['accountId']
      @api_path = api_path
      @token = response['authorizationToken']
      @authorized_at = Time.now

      # v2+ nests storage fields under apiInfo.storageApi
      # v1 has them at the top level
      if response['apiInfo'] && response['apiInfo']['storageApi']
        storage = response['apiInfo']['storageApi']
        @api_url = storage['apiUrl']
        @download_url = storage['downloadUrl']
        @recommended_part_size = storage['recommendedPartSize']
        @absolute_minimum_part_size = storage['absoluteMinimumPartSize']
        @allowed = storage['allowed']
      else
        @api_url = response['apiUrl']
        @download_url = response['downloadUrl']
        @recommended_part_size = response['recommendedPartSize']
        @absolute_minimum_part_size = response['absoluteMinimumPartSize']
        @allowed = response.fetch('allowed', nil)
      end

      Backblaze::B2::Base.base_uri "#{@api_url}#{api_path}"
      Backblaze::B2::Base.headers 'Authorization' => @token, 'Content-Type' => 'application/json'
    end

    # Re-authenticate using stored credentials.
    # Called automatically when a request fails with expired_auth_token.
    # @raise [Backblaze::AuthError] if re-authentication fails
    # @raise [Backblaze::Error] if no credentials are stored
    # @return [void]
    def reauthorize!
      raise Backblaze::Error, "No stored credentials — call login first" unless @credentials
      login(**@credentials)
    end

    # Whether the auth token is likely expired based on time.
    # B2 tokens are valid for at most 24 hours.
    # @return [Boolean]
    def token_stale?
      return true unless @authorized_at
      Time.now - @authorized_at > 23 * 3600 # refresh at 23h to avoid edge cases
    end

    def credentials_file(filename, raise_errors: true, logging: false)
      opts = nil
      ::File.open(filename, 'r') do |f|
        if ::File.extname(filename) == '.json'
          require 'json'
          opts = JSON.parse(f.read)
        else
          require 'psych'
          opts = Psych.load(f.read)
        end
      end
      parsed = {}
      [:application_key, :account_id, :api_path].each do |key|
        if opts[key.to_s].is_a? String
          parsed[key] = opts[key.to_s]
        end
      end
      if [:application_key, :account_id].inject(true) { |status, key| status && !parsed[key].nil? }
        puts "Attempting #{parsed[:account_id]}" if logging
        login(**parsed)
        true
      else
        puts "Missing params" if logging
        false
      end
    rescue => e
      puts e if logging
      raise e if raise_errors
      false
    end
  end
end
