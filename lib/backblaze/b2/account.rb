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
    end

    def login!
    end

    private

    def api
      @api ||= Api.new(@app_key_id, @app_key_secret)
    end
  end
end
