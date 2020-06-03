# frozen_string_literal: true

require "set"

module Backblaze::B2
  class FileVersion < Base
    ATTRIBUTES = Set.new(%w[action bucketId contentLength contentSha1 contentMd5 contentType fileId fileInfo fileName uploadTimestamp]).freeze

    def initialize(account, properties = {})
      super
    end

    # @return [Array<FileVersion>] list of all versions of this file
    def all_versions!
      bucket.find_versions_of_file(file_name: file_name).results
    end

    ##
    # Call B2 to get the latest version of this file if one exists
    # @return [FileVersion, nil] the latest version of the file, or nil if none
    def latest_version
      result = bucket.find_files(limit: 1, prefix: name, start_at: name).results.first
      result if result && result.name == name
    end

    # @return [Bucket] The file's bucket
    attr_reader :bucket

    def id
      self["fileId"]
    end
    alias file_id id

    def name
      self["fileName"]
    end
    alias file_name name

    def size
      self["contentLength"]
    end
    alias content_length size
    alias length size

    def action
      self["action"]
    end

    def sha1
      self["contentSha1"]
    end
    alias checksum sha1

    def md5
      self["contentMd5"]
    end

    def content_type
      self["contentType"]
    end

    def info
      self["fileInfo"]
    end
    alias file_info info

    def upload_time
      @upload_timestamp ||= long_to_time(self["uploadTimestamp"]) unless self["uploadTimestamp"].nil?
    end

    def file?
      action == "start"
    end

    def folder?
      action == "folder"
    end

    def hidden?
      action == "hide"
    end

    def uploading?
      action == "upload"
    end

    def refresh!
      set_properties(account.api.get_file_info(id))
    end

    def valid_attributes
      ATTRIBUTES
    end
  end
end
