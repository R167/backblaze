# frozen_string_literal: true

require "multi_json"

module Backblaze::B2
  module Util
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
    # @return [Net::HTTPResponse]
    def get_basic_auth(uri, username, password)
      uri = URI(uri)
      req = Net::HTTP::Get.new(uri)
      req.basic_auth(username, password)
      req["User-Agent"] = Backblaze::USER_AGENT

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end
    end

    ##
    # Construct value for Range header
    # @param [Range] range
    # @return [String] byte range
    def construct_range(range)
      range_param = nil
      if range
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
      end

      range_param
    end
  end
end
