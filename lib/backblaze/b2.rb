# frozen_string_literal: true

require 'tempfile'
require 'forwardable'
require 'digest/sha1'
require 'delegate'

require 'backblaze/b2/account'
require 'backblaze/b2/exceptions'

module Backblaze::B2
  class << self

    ##
    # Default {Account} instance
    # @return [Account] the default account
    def default_account
      @account ||= Account.new
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

    # @!macro delegated_method
    #   @!method $2(...)
    #     Deletates out to default {Account}
    #     @see Account#$2
    def_delegator :default_account, :login!
    # def_delegator :default_account,

    # @!endgroup

  end
end
