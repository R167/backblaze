require "backblaze/b2/base"
require "backblaze/b2/bucket"
require "backblaze/b2/file"
require "backblaze/b2/file_version"
require 'net/http'
require 'tempfile'
require 'digest/sha1'

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
    def login(account_id:, application_key:, api_path: '/b2api/v1/')
      options = {
        basic_auth: {username: account_id, password: application_key}
      }
      api_path = "/#{api_path}/".gsub(/\/+/, '/')
      response = HTTParty.get("https://api.backblaze.com#{api_path}b2_authorize_account", options)
      raise Backblaze::AuthError.new(response) unless response.code == 200

      @account_id = response['accountId']
      @token = response['authorizationToken']
      @api_url = response['apiUrl']
      @download_url = response['downloadUrl']
      @api_path = api_path

      Backblaze::B2::Base.base_uri "#{@api_url}#{api_path}"
      Backblaze::B2::Base.headers 'Authorization' => @token, 'Content-Type' => 'application/json'
    end

    def credentials_file(filename, raise_errors: true, logging: false)
      opts = nil
      open(filename, 'r') do |f|
        if ::File.extname(filename) == '.json'
          require 'json'
          opts = JSON.load(f)
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
        login(parsed)
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
