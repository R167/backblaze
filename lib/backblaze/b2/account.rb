# frozen_string_literal: true

module Backblaze::B2
  class Account
    extend Forwardable

    Options = Struct.new(:application_key_id, :application_key, :reauthorize, :fetch, keyword_init: true)
    FETCH_KEY = :b2_fetch

    DEFAULTS = {
      fetch: false,
      reauthorize: true
    }.freeze

    # @return [Api] Get the api for this account
    attr_reader :api

    ##
    # Get an account for accessing Backblaze
    # @param [Options, Hash] config config options for the account
    # @option config application_key_id application key id
    # @option config application_key application key
    # @option config [Boolean] reauthorize (true) automatically reauthorize when needed
    # @option config [Boolean] fetch (false) when a property hasn't been loaded on an object, automatically try and load
    #   it by calling the appropriate function to load from B2.
    def initialize(config)
      config = config.to_h if config.is_a?(Options)
      # `nil` is not a valid value, so replace nil with default value
      config = DEFAULTS.merge(config) { |_, oldval, newval| if_nil(newval, oldval) }
      @application_key_id = config[:application_key_id]
      @application_key = config[:application_key]
      @fetch = config[:fetch]
      @reauth = config[:reauthorize]

      @api = Api.new(@application_key_id, @application_key)
      @api.authorize_account if @reauth
    end

    # @!macro [attach] delegate_api_method
    #   @!method $2
    #     (see Backblaze::B2::Api#$2)
    def_delegator :api, :min_part_size
    def_delegator :api, :recommended_part_size

    # @return (see Bucket.all)
    def buckets
      Bucket.all(self)
    end

    ##
    # Create a slim bucket representation by name and id
    #
    # @param name bucket name property
    # @param id bucket id property
    # @param [Hash] properties any other bucket properties to add (included for completeness)
    # @return [Bucket] slim bucket
    def bucket(name:, id:, **properties)
      bucket_properties = {
        Bucket::NAME_KEY => name,
        Bucket::ID_KEY => id
      }.merge!(properties)
      Bucket.new(self, bucket_properties)
    end

    ##
    # Attempts to fetch a bucket from B2
    # @return [Bucket, nil] bucket pulled from backblaze
    def find_bucket(id: nil, name: nil)
      bucket = api.list_buckets(bucket_id: id, bucket_name: name)["buckets"].first
      Bucket.new(self, bucket) unless bucket.nil?
    end

    def create_bucket
    end

    def create_key
    end

    def find_keys(limit:, start_at: nil, batch_size: 1000)
      keys = []

      api.list_generic(:list_keys, id,
        start_at: start_at,
        count: limit,
        batch_size: batch_size) do |key|
        k = Key.new(key)
        if block_given?
          yield k
        else
          keys << k
        end
      end.tap { |r| r.results = keys unless block_given? }
    end

    ##
    # Temporarily override fetch setting and allow fetching from B2 within the block
    # @yield block to execute with fetch
    # @return last value in block
    def with_fetch(fetch = true, &block)
      restore = Thread.current[FETCH_KEY]
      Thread.current[FETCH_KEY] = fetch
      block.call
    ensure
      Thread.current[FETCH_KEY] = restore
    end

    ##
    # Temporarily override fetch setting and disable fetching from B2 within the block
    # @yield block to execute without fetch
    # @return (see #with_fetch)
    def without_fetch(&block)
      with_fetch(false, &block)
    end

    # @return [Boolean] if the current scope should attempt to fetch
    def fetch?
      Thread.current[FETCH_KEY].nil? ? @fetch : Thread.current[FETCH_KEY]
    end

    private

    # @return default if value is nil, else, value
    def if_nil(value, default)
      value.nil? ? default : value
    end
  end
end
