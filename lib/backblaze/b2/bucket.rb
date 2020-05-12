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

      ##
      # Create a minimal version of a bucket comprised of the name and id.
      #
      # Some operations in the B2 api require just the bucket_id while others require the name. It is best practice
      # to make sure you always instantiate new objects with at least these two fields (when you've been keeping them
      # in storage, e.g. saved in redis), otherwise you may end up with **way** more api requets than you expect your
      # application should be making.
      def from_storage(name:, id:, api: nil)
        Bucket.new(api=api, attrs: {bucket_name: name, bucket_id: id})
      end

      def coerce(obj, api=nil)
        if obj.is_a?(Bucket)
          obj
        elsif obj.is_a?(Hash)
          if obj.include?(:bucket_name) || obj.include?('bucketName')
            Bucket.from_api(api, attrs: obj)
          elsif obj.include?(:name) && obj.include?(:id)
            Bucket.from_storage(api: api, **obj)
          else
            raise KeyError, "Hash must have name/id keys"
          end
        else
          new(api, attrs: {bucket_id: bucket})
        end
      end
    end

    def all_files!(&block)
      FileVersion.find_files(bucket: self, count: :all, &block)
    end

    def refresh!
      set_attributes!(api.list_buckets(bucket))
    end

    def update!(merge: true)

    end
  end
end
