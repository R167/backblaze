require "backblaze/b2/account"
require "backblaze/b2/bucket"
require "backblaze/b2/file"

module Backblaze
  class B2

    class << self
      attr_reader :account_id, :token, :api_url, :download_url

      ##
      # Authenticates with the server to get the authorization data. Raises an error if there is a problem
      #
      # @param [#to_s] account_id the account id
      # @param [#to_s] application_key the private app key
      # @raise [Backblaze::Error::AuthError] if unable to authenticate
      # @return [void]
      def login!(account_id:, application_key:)
        options = {
          basic_auth: {username: account_id, password: application_key}
        }
        response = HTTParty.get("https://api.backblaze.com/b2api/v1/b2_authorize_account", options)
        raise Backblaze::Error::AuthError.new unless response.code == 200

        @@account_id = response['accountId']
        @@token = response['authorizationToken']
        @@api_url = response['apiUrl']
        @@download_url = response['downloadUrl']
      end

      ##
      # Authenticates with the server to get the authorization data. Does not explode on failure
      #
      # @param (see login!)
      # @return [true, false] whether login was successful
      def login(account_id:, application_key:)
        begin
          login!(account_id: account_id, application_key: application_key)
          true
        rescue Backblaze::Error::AuthError => e
          false
        end
      end
    end
  end
end
