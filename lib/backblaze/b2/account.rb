# frozen_string_literal: true

module Backblaze::B2
  class Account
    extend Forwardable

    attr_reader :api

    ##
    # Get an account for accessing Backblaze
    # @param application_key_id (see Api#initialize)
    # @param application_key (see Api#initialize)
    # @raise [ValidationError] Required parameters must be set to valid values
    def initialize(application_key_id:, application_key:, reauthorize: true)
      @application_key = application_key
      @application_key_id = application_key_id

      unless can_login?
        raise ValidationError, "Conditions not satisfied for logging in. Did you provide API key and call {Account#login!}?"
      end

      @reauth = reauthorize
      @api = Api.new(@application_key_id, @application_key)
      @api.authorize_account
    end

    ##
    # (see Api#with_persistent_connection)
    def with_persistent_connection(&block)
      api.with_persistent_connection(&block)
    end

    def buckets
      Bucket.all(api)
    end

    private

    ##
    # Check if all the parameters are set to allow login
    def can_login?
      !!(@application_key && @application_key_id)
    end
  end
end
