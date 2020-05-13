# frozen_string_literal: true

require 'tempfile'
require 'stringio'
require 'digest'

module Backblaze::B2
  ##
  # Manages uploading a file.
  #
  # Several modes of uploading are supported. The simplest case just passing in the api and letting everything
  # be handled "magically"
  class Upload

    MODES = %i(auto one_shot large_file).freeze

    DEFAULT_DELIMITER = '/'
    LARGE_FILE_OPTIONS = {
      max_threads: 4,
      part_size: nil,
    }.freeze

    attr_accessor :bucket, :object, :file_name, :prefix, :mode, :threads, :async, :auto_retry, :delimiter
    attr_reader :large_file_opts, :on_success, :on_failure, :file_info

    ##
    # Create a managed upload for this file
    # @param [Bucket] bucket Bucket to upload this file to
    # @param [#read, String] object IO object/File/String to upload
    # @param [String] file_name Name of the file. This will be prefixed by `prefix`, and joined using `delimiter` if specified
    # @param [:auto, :one_shot, :large_file] mode How the file will be uploaded. By default, follow Backblaze's recommendation
    #   from recommendedPartSize. The file must be at least 5MB to upload as a large file. Refer to {LargeFile}
    def initialize(bucket: nil, object: nil, file_name: nil, prefix: nil, mode: :auto, async: false, auto_retry: nil, large_file_opts: {}, file_info: {})
      @bucket = bucket
      @object = object
      @mode = mode
      @threads = threads
      @async = async
      @auto_retry = auto_retry
      @delimiter = DEFAULT_DELIMITER
      @large_file_opts = LARGE_FILE_OPTIONS.merge(large_file_opts)
      @file_info = file_info
    end

    def background_upload!
      check_locked!
      @async = true
      upload!
    end

    def upload!
      check_locked!
      @locked = true
      self.freeze

      if async
        Thread.new { upload_file }
      else
        upload_file
      end
    end

    ##
    # Define a success callback
    #
    # When an upload is a success, this block is called with the file as the parameter
    # @raise [ArgumentError] When multiple callbacks supplied
    # @return [void]
    # @overload on_success(proc)
    #   @param [Proc] callback Proc to call with file
    # @overload on_success(&block)
    #   @yieldparam [FileVersion] file The successfully uploaded file
    def on_success(callback = nil, &block)
      raise ArgumentError, "Can only specify one block as a parameter" if block && callback
      @on_success = callback || block
    end

    ##
    # Define a failure callback
    #
    # When an upload is a failure, this block is called with the error as the parameter
    # @raise [ArgumentError] When multiple callbacks supplied
    # @return [void]
    # @overload on_failure(proc)
    #   @param [Proc] callback Proc to call with error
    # @overload on_failure(&block)
    #   @yieldparam [ApiError] err Error encountered in upload
    def on_failure(callback = nil, &block)
      raise ArgumentError, "Can only specify one block as a parameter" if block && callback
      @on_failure = callback || block
    end

    def valid?
      !!(file_name && !file_name.empty? && object && MODES.include?(mode))
    end

    class LargeFile

    end

    class OneShotFile
      include UploadPart

      attr_reader :config

      ##
      # @param [Upload] config The frozen upload object which has all config params
      def initialize(config)
        @config = config
      end

      def upload_url
        config.bucket.upload_url
      end

      def upload

      end
    end

    module UploadPart
      B2_PREFIX = "X-Bz-Info-"

      ##
      # @return [HTTP::Response]
      # @raise [ApiError] on failed upload
      def upload_part(file:, auth:, url:, headers: {}, b2_headers: {})
        b2_headers = b2_headers.merge({"Content-SHA1" => file_digest(file)})
        b2_headers.transform_keys! { |key| "#{B2_PREFIX}#{key}" }
        headers = headers.merge(b2_headers, { content_length: file.size })

        response = HTTP[**headers].auth(auth).post(url, body: file)
        if file.respond_to?(:unlink)
          file.unlink
        end
        file.close

        if response.status.success?
          response
        else
          raise api_error(response)
        end
      end

      ##
      # Get the SHA1 of the file
      # @return [String] Hex sha1
      def file_digest(file)
        Digest::SHA1.file(file).hexdigest
      end
    end

    private

    def full_file_name
      if prefix
        "#{prefix}#{delimiter}#{file_name}"
      else
        file_name
      end
    end

    ##
    # Get a "file like" object
    # @return [File, Tempfile]
    def file_object
      # Hack, because I need files
      if object.is_a?(String)
        object = StringIO.new(object)
      end

      case object
      when File, Tempfile
        object
      else
        if object.respond_to?(:read)
          Tempfile.new.tap do |tmp_file|
            IO.copy_stream(object, tmp_file)
            object.close
          end
        else
          raise ArgumentError, "object does not respond to #read"
        end
      end
    end

    def upload_file

    end

    ##
    # Raise an error if we try and modify an upload after starting it
    # @raise [UploadInProgressError]
    def check_locked!
      raise UploadInProgressError, "Upload already in progress. Cannot modify" if @locked
    end
  end
end
