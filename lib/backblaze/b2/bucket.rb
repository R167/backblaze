# frozen_string_literal: true

module Backblaze::B2
  class Bucket < Base
    include Resource
    # @!parse
    #   extend Resource::ClassMethods

    ATTRIBUTES = %w{accountId bucketId bucketInfo bucketName bucketType corsRules lifecycleRules options revision}.freeze
    create_attributes ATTRIBUTES

    alias_method :name, :bucket_name
    alias_method :id, :bucket_id

    class << self
      def all(api)
        api.list_buckets['buckets'].map do |b|
          Bucket.from_api(api, b)
        end
      end
    end

    def refresh!
      set_attributes!(api.list_buckets(bucket))
    end

    def update!(merge: true)

    end
  end
end
