module Backblaze
  ##
  # Base Backblaze error class
  # @abstract
  class Error < StandardError
  end

  ##
  # Basic needs for error messages.
  # @note this could be abstract, but just keeps things simple.
  class RequestError < Error
    ##
    # Creates the Error
    # @param [HTTParty::Response] response the json response
    def initialize(response)
      @response = response
    end

    ##
    # The response from the server
    # @return [HTTParty::Response] the response
    attr_reader :response

    ##
    # The Backblaze B2 error code
    # @return [String] error code
    def code
      self['code']
    end

    ##
    # The Backblaze B2 request status
    # @return [Integer] status code
    def status
      self['status']
    end

    ##
    # The Backblaze B2 error message which is a human explanation
    # @return [String] the problem in human words
    def message
      self['message']
    end

    ##
    # Shortcut to access the response keys
    # @return [Object] the object stored at `key` in the response
    def [](key)
      @response[key]
    end
  end

  ##
  # Errors destroying file versions
  class DestroyErrors < Error
    ##
    # Creates the Error
    # @param [Array<Backblaze::FileError>] errors errors raised destroying files
    def initialize(errors)
      @errors = errors
    end

    ##
    # The Backblaze B2 error messages which broke things
    # @return [Array<Backblaze::FileError>] errors errors raised destroying files
    attr_reader :errors
  end

  ##
  # Error class for authentication errors
  class AuthError < RequestError; end

  ##
  # Error class for bucket errors
  class BucketError < RequestError; end

  ##
  # Error class for file errors
  class FileError < RequestError; end
end
