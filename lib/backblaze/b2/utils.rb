# frozen_string_literal: true

require "multi_json"
require "net/http"

module Backblaze::B2
  ##
  # Helper utilities
  module Utils
    extend self

    ##
    # Helper for symbolizing a key from "camelCase" to :snake_case
    #
    # Heavily based on the `underscore` method from ActiveSupport
    # @param [String] key generally a JSON key
    # @return [Symbol] key to handle in ruby
    # @see https://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-underscore
    def symbolize_key(key)
      word = key.is_a?(String) ? key.dup : key.to_s
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/.freeze, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/.freeze, '\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word.to_sym
    end

    ##
    # Helper for camel casing a symbol for JSON
    # @param [Symbol, String] key snake_case to make camelCase
    # @return [String] a camelCase string for JSON
    def camelize_key(key)
      words = key.to_s.split("_")
      words.each_with_index.map { |word, index| index.zero? ? word : word.capitalize }.join("")
    end

    ##
    # Convert from the long format used by java and B2 to a ruby {Time}
    def long_to_time(long)
      return timestamp unless long.is_a?(Integer)
      Time.at(0, long, :millisecond)
    end

    ##
    # Convert from a ruby {Time} to the long format used by java
    def time_to_long(time)
      return time unless time.is_a?(Time)
      time.to_i * 1000 + time.usec / 1000
    end

    protected

    # (see Backblaze::B2.api_error)
    def api_error(response)
      Backblaze::B2.api_error(response)
    end

    # @param [Net::HTTPResponse] response HTTP response
    # @param [Boolean] symbolize symbolize keys
    # @return result of parsing json
    def parse_json(response, symbolize = false)
      MultiJson.load(response.body, symbolize_keys: symbolize)
    end

    # @param [Hash] data data to dump to json
    # @return [String] json
    def dump_json(data)
      MultiJson.dump(data)
    end

    # @param [URI, String] uri
    # @param [String] username
    # @param [String] password
    # @param [Integer] timeout timeout duration for this request
    # @return [Net::HTTPResponse]
    def get_basic_auth(uri, username, password, timeout: 5)
      uri = URI(uri)
      req = Net::HTTP::Get.new(uri)
      req.basic_auth(username, password)
      req["User-Agent"] = Backblaze::USER_AGENT

      http_request(uri, timeout: timeout) do |http|
        http.request(req)
      end
    end

    ##
    # Construct value for Range header
    # @param [Range, String] range
    # @return [String] byte range
    def construct_range(range)
      range_param = nil
      if range.is_a?(Range)
        range_param = +"bytes="
        # Make range start at begin or 0 (if negative/unbounded)
        range_param << [(range.begin || 0), 0].max.to_s
        range_param << "-"
        # if we for some reason got an endless range...
        range_param << (range.end && range.exclude_end? ? range.end - 1 : range.end).to_s
      else
        range_param = range.to_s
      end

      range_param
    end

    # @param [Numeric] seconds until timeout
    # @return [Hash] {Net::HTTP} timeout parameters
    def all_timeouts(seconds)
      {open_timeout: seconds, read_timeout: seconds, write_timeout: seconds}
    end

    # @param [URI] uri
    def http_request(uri, timeout: 10, **kwargs, &block)
      Net::HTTP.start(uri.host, uri.port, uri.host, uri.port, use_ssl: uri.scheme == "https", **all_timeouts(timeout), **kwargs, &block)
    end
  end
end
