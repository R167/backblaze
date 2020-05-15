# frozen_string_literal: true

module Backblaze::B2
  class FileVersion < Base
    include Resource

    ATTRIBUTES = %w[accountId action bucketId contentLength contentSha1 contentType fileId fileInfo fileName uploadTimestamp]
    CONFIG = %i[content_type file_info file_name]

    create_attributes ATTRIBUTES

    alias name file_name
    alias id file_id
    alias size content_length

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

    # @return [Array<FileVersion>] list of all versions of this file
    def all_versions!
      bucket.find_versions_of_file(file_name: file_name).results
    end

    ##
    # Call B2 to get the latest version of this file if one exists
    # @return [FileVersion, nil] the latest version of the file, or nil if none
    def latest!
      result = bucket.find_files(count: 1, prefix: name, start_at: name).results.first
      result if result && result.name == name
    end

    # @return [Bucket] The file's bucket
    attr_reader :bucket

    class << self
    end
  end
end
