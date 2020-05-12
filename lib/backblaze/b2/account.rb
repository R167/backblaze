# frozen_string_literal: true

module Backblaze::B2
  class Account
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

    def api
      @api ||= Api.new(@application_key_id, @application_key)
    end
  end
end
