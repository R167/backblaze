# frozen_string_literal: true

require "set"

module Backblaze::B2
  class Key < Base
    KEY_CAPABILITIES = %w[listKeys writeKeys deleteKeys].freeze
    BUCKET_CAPABILITIES = %w[listBuckets listAllBucketNames writeBuckets deleteBuckets].freeze
    FILE_CAPABILITIES = %w[listFiles readFiles shareFiles writeFiles deleteFiles].freeze

    ALL_CAPABILITIES = (KEY_CAPABILITIES + BUCKET_CAPABILITIES + FILE_CAPABILITIES).freeze

    CAPABILITY_SETS = {
      all_keys: KEY_CAPABILITIES,
      all_buckets: BUCKET_CAPABILITIES,
      all_files: FILE_CAPABILITIES,
      all: ALL_CAPABILITIES
    }.freeze

    ATTRIBUTES = Set.new(%w[keyName applicationKeyId capabilities expirationTimestamp bucketId namePrefix options]).freeze

    # Create helper methods for checking capabilities.
    # They are of the form `list_keys? => Boolean`
    ALL_CAPABILITIES.each do |capability|
      key_name = Utils.symbolize_key(capability)
      define_method(:"#{key_name}?") do
        capabilities.include?(capability)
      end
    end

    def initialize(account, properties = {})
      super
      self["capabilities"] = Set.new(self["capabilities"]).freeze
    end

    def refresh!
      nil
    end

    def name
      self["keyName"]
    end
    alias_method :key_name, :name

    def id
      self["applicationKeyId"]
    end
    alias_method :application_key_id, :id

    def secret
      self["applicationKey"]
    end
    alias_method :application_key, :secret

    def expires?
      !expiration.nil?
    end

    def expiration
      @expiration ||= long_to_time(self["expirationTimestamp"]) unless self["expirationTimestamp"].nil?
    end

    def prefix
      self["namePrefix"]
    end

    # @return [Set] key capabilities
    def capabilities
      self["capabilities"]
    end

    def bucket_locked?
      !self["bucketId"].nil?
    end

    def bucket_id
      self["bucketId"]
    end

    def can_access_bucket?(bucket)
      !bucket_locked? || bucket_id == bucket.id
    end

    def bucket
      if bucket_locked? && !@bucket
        bucket_properties = {
          Bucket::NAME_KEY => self["bucketName", fetch: false],
          Bucket::ID_KEY => bucket_id
        }
        @bucket = Bucket.new(account, bucket_properties)
      end
      @bucket
    end

    def valid_attributes
      ATTRIBUTES
    end
  end
end
