# frozen_string_literal: true

module Backblaze::B2
  class Bucket < Base
    include Resource

    ATTRIBUTES = %w{accountId bucketId bucketInfo bucketName bucketType corsRules lifecycleRules options revision}.freeze
    create_attributes ATTRIBUTES

    alias_method :name, :bucket_name
    alias_method :id, :bucket_id

    class << self
      ##
      # Call the api to get all buckets in the account
      # @param [Account] account Account to search for buckets in
      # @return [Array<Bucket>] all buckets in the account
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
      # @return [Bucket]
      def from_storage(name:, id:, account: nil)
        Bucket.new(account, attrs: {bucket_name: name, bucket_id: id})
      end

      ##
      # Try a variety of techniques to coerce an object into a bucket
      #
      # @param [Bucket, Hash, String<:bucket_id>] obj
      # @param [Account] account acount this bucket is associated with
      # @return [Bucket]
      # @raise [KeyError] when the object is a Hash, but doesn't have the proper keys
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

    ##
    # Search the bucket for all visible files
    #
    # Warning: This will make a lot of API calls. Be careful about calling it. It is generally better to use the methods
    # such as {FileVersion.find_files} and {FileVersion.find_file_versions} as these give you more fine-grained control
    # over what and how much data you are fetching.
    # @param count (see FileVersion.find_files)
    # @yield Each file in the bucket
    # @yieldparam [FileVersion] file the current file
    # @return [Hash] information about the last iteration
    def all_files!(count: :all, &block)
      FileVersion.find_files(bucket: self, count: count, &block)
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

  end
end
