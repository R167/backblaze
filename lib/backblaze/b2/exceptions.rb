# frozen_string_literal: true

require 'multi_json'

module Backblaze::B2
  ##
  # Generice B2 exception that all others inherit from
  # @abstract
  class Error < StandardError; end

  ##
  # Errors encountered when calling the api
  # @see https://www.backblaze.com/b2/docs/calling.html#error_handling
  class ApiError < Error
    attr_reader :status, :code, :message, :body

    def initialize(response)
      @status = response.code
      body = response.body.to_s
      begin
        data = MultiJson.load(body)
        # We want a key error if the data is bad
        @code = data.fetch('code')
        @message = data.fetch('message')
      rescue MultiJson::ParseError, KeyError
        @code = 'mangled_response'
        @message = 'Could not parse bad response from server. Refer to #body'
        # Only persist when we get mangled data from the server
        @body = body
      end
    end
  end
end
