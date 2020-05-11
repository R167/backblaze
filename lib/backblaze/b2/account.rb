# frozen_string_literal: true

module Backblaze::B2
  class Account
    # Account key and secrets
    attr_writer :application_key_id, :application_key


    ##
    # Get an account for accessing Backblaze
    def initialize(options)
      @api = Api.new(app_key_id, app_key_secret)
    end

    def login!
    end
  end
end
