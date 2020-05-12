# frozen_string_literal: true

module Backblaze::B2
  class Account
    extend Forwardable

    # Account key id
    attr_writer :application_key_id
    # Account key secret
    attr_writer :application_key

    ##
    # Get an account for accessing Backblaze
    def initialize(options = {})
      @application_key = options[:application_key]
      @application_key_id = options[:application_key_id]

      api.authorize_account
    end

    ##
    # (see Api#with_persistent_connection)
    def with_persistent_connection(&block)
      api.with_persistent_connection(&block)
    end

    ##
    # Get the {Api} instance for this account.
    def api
      @api ||= Api.new(@application_key_id, @application_key)
    end
  end
end
