# frozen_string_literal: true

require 'tempfile'
require 'forwardable'
require 'digest/sha1'
require 'delegate'

require 'backblaze/b2/account'
require 'backblaze/b2/api'
require 'backblaze/b2/exceptions'

module Backblaze::B2
  ENV_KEY_ID = 'BACKBLAZE_B2_API_KEY_ID'
  ENV_KEY_SECRET = 'BACKBLAZE_B2_API_KEY'

  class << self
    extend Forwardable

    ##
    # Default {Account} instance
    # @return [Account] the default account
    def default_account
      @account ||= create_account
    end

    ##
    # Load .env files
    def dotenv!
      require 'dotenv/load'
    end

    ##
    # Configure the default Account
    # @yield [acct] Configure the default account
    # @yieldparam [Account] acct Default account to configure
    # @example Setting the application key
    #   Backblaze::B2.config do |c|
    #     c.application_key_id = "master_account_key_id"
    #     c.application_key = "master_account_key"
    #   end
    # @return [void]
    def config
      yield default_account
    end

    # @!group Delegated Methods

    # @!macro [attach] delegate_account_method
    #   @!method $2
    #     (see Backblaze::B2::Account#$2)
    def_delegator :default_account, :api
    def_delegator :default_account, :with_persistent_connection

    # @!endgroup

    private

    def create_account
      Account.new({
        application_key_id: ENV[ENV_KEY_ID],
        application_key: ENV[ENV_KEY_SECRET]
      })
    end

  end
end
