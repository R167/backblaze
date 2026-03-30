module Backblaze
  ##
  # Base Backblaze error class
  # @abstract
  class Error < StandardError
  end

  ##
  # Basic needs for error messages.
  class RequestError < Error
    attr_reader :response

    ##
    # Creates the Error
    # @param [HTTParty::Response, Hash] response the json response
    def initialize(response)
      @response = response
      super("#{self['code']}: #{self['message']} (status: #{self['status']})")
    end

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
    # Shortcut to access the response keys
    # @return [Object] the object stored at `key` in the response
    def [](key)
      @response[key]
    end
  end

  ##
  # Errors destroying file versions
  class DestroyErrors < Error
    attr_reader :errors

    ##
    # Creates the Error
    # @param [Array<Backblaze::FileError>] errors errors raised destroying files
    def initialize(errors)
      @errors = errors
      super("#{errors.size} file(s) failed to delete")
    end
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
