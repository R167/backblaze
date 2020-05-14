# frozen_string_literal: true

module Backblaze::B2
  class FileVersion < Base
    include Resource

    ATTRIBUTES = %w(accountId action bucketId contentLength contentSha1 contentType fileId fileInfo fileName uploadTimestamp)
    CONFIG = %i(content_type file_info file_name)

    create_attributes ATTRIBUTES

    alias_method :name, :file_name
    alias_method :id, :file_id
    alias_method :size, :content_length

    def initialize(account = nil, bucket: nil, attrs: {})
      if bucket.is_a?(Bucket)
        @bucket = bucket
      else
        bucket_params = attrs.slice(:bucket_name, :bucket_id)
        if bucket.is_a?(Hash)
          bucket_params.merge!(bucket)
        end

      end

      super(account, attrs: attrs)
    end

    # @return [Array<FileVersion>] List of all ovrsions of this file
    def all_versions!
      self.class.find_versions_of_file(bucket: bucket, file_name: file_name)
    end

    ##
    # Call B2 to get the latest version of this file if one exists
    # @return [FileVersion, nil] The latest version of the file, or nil if none
    def latest!
      result = self.class.find_files(bucket: bucket, count: 1, prefix: name, start_at: name).first
      result if result && result.name == name
    end

    # @return [Bucket] The file's bucket
    def bucket
      @bucket
    end

    class << self
    end
  end
end
