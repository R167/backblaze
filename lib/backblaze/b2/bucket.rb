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
      def all(account)
        account.api.list_buckets['buckets'].map do |bucket|
          Bucket.from_api(account, bucket)
        end
      end

      ##
      # Create a minimal version of a bucket comprised of the name and id.
      #
      # Some operations in the B2 api require just the bucket_id while others require the name. It is best practice
      # to make sure you always instantiate new objects with at least these two fields (when you've been keeping them
      # in storage, e.g. saved in redis), otherwise you may end up with **way** more api requets than you expect your
      # application should be making.
      def from_storage(name:, id:, account: nil)
        Bucket.new(account, attrs: {bucket_name: name, bucket_id: id})
      end

      def coerce(obj, account = nil)
        if obj.is_a?(Bucket)
          obj
        elsif obj.is_a?(Hash)
          if obj.include?(:bucket_name) || obj.include?('bucketName')
            Bucket.from_api(account, attrs: obj)
          elsif obj.include?(:name) && obj.include?(:id)
            Bucket.from_storage(account: account, **obj)
          else
            raise KeyError, "Hash must have name/id keys"
          end
        else
          new(account, attrs: {bucket_id: bucket})
        end
      end
    end

    def all_files!(&block)
      FileVersion.find_files(bucket: self, count: :all, &block)
    end

    ##
    # Get an upload url and authorization
    # @return [Hash] :auth, :url, and :bucket_id
    def upload_url
      upload = account.api.get_upload_url
      {
        auth: upload['authorizationToken'],
        url: upload['uploadUrl'],
        bucket_id: upload['bucketId']
      }
    end

    # def refresh!
    #   set_attributes!(account.api.list_buckets(bucket))
    # end

    def update!(merge: true)

    end
  end
end
