# frozen_string_literal: true

module Backblaze::B2
  ##
  # Base class with helpers for B2 classes
  # @abstract
  class Base
    ##
    # Result of a "list" call
    # @!attribute [rw] start_at
    #   Where to start the next iteration
    # @!attribute [rw] count
    #   @return [Integer] number of results returned
    # @!attribute [rw] stop
    #   @return [Boolean] if the listing reached the end of all listable results
    # @!attribute [rw] results
    #   @return [Array, nil] optional results list
    # @!parse
    #   alias_method :to_a, :results
    ListResult = Struct.new(:start_at, :count, :stop, :results) do
      alias_method :to_a, :results
    end

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

      ##
      # Provide a generic interface for getting a list of values from the account
      # @param [Account] account
      # @param [Symbol] method_name The name of the list function to call (invoked on `account.api`)
      # @param [Array] args Args to splat into the list method
      # @param [Hash] options Options hash to forward to the api
      # @option options [Numeric, :all] :count Stop after fetching this many files. When passed a positive value,
      #   this is the case. If you want no limit on the results returned, use the special value `:all`. This will set
      #   count to Float::INFINITE.
      # @option options [Integer] :batch_size Max number of requests to send
      # @option options :start_at First place to start at
      # @yield Returns each object that should be processed
      # @yieldparam [Hash] item Each item returned by the api
      # @return [ListResult] Last iterator and total number or results returned
      def api_list(account, method_name, *args, **options, &block)
        count = options.delete(:count)
        batch_size = options.delete(:batch_size) { 1_000 }
        total = 0
        last_count = 1
        if count == :all
          count = Float::INFINITY
        elsif count <= 0
          raise ArgumentError, "count must be positive"
        end

        last_iter = nil

        account.with_persistent_connection do
          while total < count && last_count > 0
            batch_count = [batch_size, count - total].min

            options[:count] = batch_count
            data = account.api.public_send(method_name, *args, **options)
            data_key = data[:iter][:key]
            total += data[data_key].length
            last_iter = data[:iter]

            data[data_key].each(&block)

            if data[:iter][:stop]
              break
            else
              options[:start_at] = data[:iter][:start_at]
            end
          end
        end

        ListResult.new(last_iter[:start_at], total, last_iter[:stop], nil)
      end
    end
  end
end
