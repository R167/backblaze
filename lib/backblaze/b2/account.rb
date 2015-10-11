module Backblaze::B2
  class Account < Base

    ##
    # Authenticates with the server to get the authorization data
    #
    # @param [#to_s] account_id: the account id
    # @param [#to_s] application_key: the private app key
    # @raise [Backblaze::Error::AuthError] if unable to authenticate
    # @return [Backblaze::B2::Account] the new account
    def initialize(account_id:, application_key:)

    end
  end
end
