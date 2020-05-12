# frozen_string_literal: true

require 'tempfile'
require 'forwardable'
require 'delegate'

require 'backblaze/b2/account'
require 'backblaze/b2/api'
require 'backblaze/b2/base'
require 'backblaze/b2/exceptions'
require 'backblaze/b2/resource'
require 'backblaze/b2/bucket'

##
# Core module for accessing the B2 api.
#
# For most use cases, this module should be more than sufficient for accessing B2. There is a {.default_account} that
# has most of the methods you need delegated to it. If you find yourself needing a full {Account} object, just access
# it through `Backblaze::B2.default_account`. The default account is automatically created from credentials found in
# the environment variables `BACKBLAZE_B2_API_KEY_ID` and `BACKBLAZE_B2_API_KEY`. By design, you cannot use the default
# account until you have either explictly provisioned it by calling {.login!} or configured it with {.config}
#
# Following the Rails pattern of initializers, you can call {.config} and set attributes on the yielded object.
#
# @example (see .config)
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
    # Configure the default Account
    # @yield Configure the default account
    # @yieldparam [AccountOptions] c Account options. Can be called with setters for all of the keyword params of
    #   {Account#initialize}
    # @example Setting the application key
    #   Backblaze::B2.config do |c|
    #     c.application_key_id = "master_account_key_id"
    #     c.application_key = "master_account_key"
    #   end
    # @return [void]
    def config
      # Create the options obeject and
      @config ||= AccountOptions.new
      @config.application_key_id ||= ENV[ENV_KEY_ID]
      @config.application_key ||= ENV[ENV_KEY_SECRET]

      if block_given?
        yield @config
      else
        @config
      end
    end

    ##
    # Trigger automatic config for the default account
    def login!
      config unless @config
    end

    ##
    # Resets config and default account back to being unset
    def reset!
      @config = nil
      @account = nil
    end

    # @!group Delegated Methods

    # @!macro [attach] delegate_account_method
    #   @!method $2
    #     (see Backblaze::B2::Account#$2)
    def_delegator :default_account, :with_persistent_connection

    # @!endgroup

    private

    AccountOptions = Struct.new(:application_key_id, :application_key, :reauthorize)

    def create_account
      if @config
        # We need to splat them...
        Account.new(**@config.to_h)
      else
        raise ValidationError, "You must config or login! before trying to access default_account."
      end
    end

  end
end
