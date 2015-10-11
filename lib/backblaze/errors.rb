module Backblaze
  ##
  # Base Backblaze error class
  # @abstract
  class Error < StandardError; end

  ##
  # Error class for authentication errors
  class AuthError < Error

    ##
    # Creates the AuthError
    # @param [HTTParty::Response] response the json response
    def initialize(response)
      @response = response
    end

    ##
    # The response from the server
    # @return [HTTParty::Response] the response
    def response
      @response
    end

    ##
    # Shortcut to access the response keys
    # @return [Object] the object stored at `key` in the response
    def [](key)
      @response[key]
    end
  end
end
