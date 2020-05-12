# frozen_string_literal: true

module Backblaze::B2
  ##
  # Base class with helpers for B2 classes
  # @abstract
  class Base

    class << self
      ##
      # Helper method for symbolizing a key from "camelCase" to :snake_case
      #
      # Heavily based on the `underscore` method from ActiveSupport
      # @see https://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-underscore
      def symbolize_key(key)
        word = key.dup
        word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
        word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
        word.tr!("-", "_")
        word.downcase!
        word.to_sym
      end

      # protected

      ##
      # Provide a generic interface for getting a list of values from the api
      # @param [Api] api
      # @param [Symbol] method_name The name of the list function to call (invoked on `api`)
      # @param [Array] args Args to splat into the list method
      # @param [Hash] options Options hash to forward to the api
      # @option options [Numeric, :all] :count Stop after fetching this many files. When passed a positive value,
      #   this is the case. If you want no limit on the results returned, use the special value `:all`. This will set
      #   count to Float::INFINITE.
      # @option options [Integer] :batch_size Max number of requests to send
      # @option options :start_at First place to start at
      # @yield Returns each object that should be processed
      # @yieldparam [Hash] item Each item returned by the api
      # @return
      def api_list(api, method_name, *args, **options, &block)
        count = options.delete(:count)
        batch_size = options.delete(:batch_size) { 1_000 }
        total = 0
        last_count = 1
        if count == :all
          count = Float::INFINITY
        elsif count <= 0
          raise ArgumentError, "count must be positive"
        end

        api.with_persistent_connection do
          while total < count && last_count > 0
            batch_count = [batch_size, count - total].min

            data = api.public_send(method_name, *args, **options)
            data_key = data[:iter][:key]

            data[data_key].each(&block)
            total += data[data_key].length

            if data[:iter][:stop]
              break
            else
              options[:start_at] = data[:iter][:start_at]
            end
          end
        end

        total
      end
    end

  end
end
