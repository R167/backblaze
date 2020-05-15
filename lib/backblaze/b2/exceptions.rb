# frozen_string_literal: true

require "multi_json"

module Backblaze::B2
  ##
  # Generic B2 exception that all others inherit from
  # @abstract
  class Error < StandardError; end

  ##
  # Validations need to pass before action can occur
  class ValidationError < Error; end

  ##
  # Upload is already in progress. Cannot change
  class UploadInProgressError < Error; end

  ##
  # Errors encountered when calling the api
  # @see https://www.backblaze.com/b2/docs/calling.html#error_handling
  class ApiError < Error
    attr_reader :status, :code, :retry_after

    def initialize(msg = "", code = "__unspecified", status = -1, retry_after = nil)
      @status = status
      @code = code
      @retry_after = (!!retry_after ? retry_after.to_i : retry_after)
      super(msg)
    end

    # Does this error have a retry after timeout
    def has_retry?
      !!@retry_after
    end

    def inspect
      "#<#{self.class.name}:#{" retry" if has_retry?} code=#{code} status=#{status}: #{message}>"
    end
  end

  # @!group Exceptions

  AuthTokenException = Class.new(ApiError)
  BadRequestException = Class.new(ApiError)
  BucketRevisionException = Class.new(ApiError)
  NotAuthorizedException = Class.new(ApiError)
  NotFoundException = Class.new(ApiError)
  RequestTimeoutException = Class.new(ApiError)
  RetryLater = Class.new(ApiError)
  ServerError = Class.new(ApiError)
  UnsupportedException = Class.new(ApiError)
  UsageExceededException = Class.new(ApiError)

  ##
  # Mapping of Backblaze error codes to native exceptions
  # @note This list is not meant to be comprehensive, only to map the most common cases
  EXCEPTION_MAP = {
    "bad_auth_token" => AuthTokenException,
    "bad_request" => BadRequestException,
    "cap_exceeded" => UsageExceededException,
    "download_cap_exceeded" => UsageExceededException,
    "conflict" => BucketRevisionException,
    "duplicate_bucket_name" => BadRequestException,
    "expired_auth_token" => AuthTokenException,
    "not_found" => NotFoundException,
    "range_not_satisfiable" => BadRequestException,
    "service_unavailable" => AuthTokenException,
    "too_many_buckets" => BadRequestException,
    "transaction_cap_exceeded" => UsageExceededException,
    "unauthorized" => NotAuthorizedException,
    "unsuported" => UnsupportedException,

    "400" => BadRequestException,
    "401" => NotAuthorizedException,
    "403" => UsageExceededException,
    "408" => RequestTimeoutException,
    "429" => RetryLater,
    "500" => ServerError,
    "503" => RetryLater,
    "508" => ServerError
  }.freeze

  # @!endgroup

  ##
  # Parse the error response message and create the correct exception type based on the code
  # @param [Net::HTTPResponse] response response object to parse
  # @raise [ApiError] some subclass of {ApiError} based on the error message
  # @api private
  # @!visibility private
  def self.api_error(response)
    status = response.code
    retry_after = response["Retry-After"]
    body = response.body.to_s
    begin
      data = MultiJson.load(body)
      # We want a key error if the data is bad
      code = data.fetch("code")
      message = data.fetch("message")
    rescue MultiJson::ParseError, KeyError
      code = "mangled_response"
      message = "Could not parse bad response from server: #{body}"
    end

    find_exception_class(code, status).new(message, code, status.to_i, retry_after)
  end

  def self.find_exception_class(code, status)
    if EXCEPTION_MAP.include?(code)
      EXCEPTION_MAP[code]
    elsif EXCEPTION_MAP.include?(status)
      EXCEPTION_MAP[status]
    else
      ApiError
    end
  end
  private_class_method :find_exception_class
end
