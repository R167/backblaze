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

    Config = Struct.new()

    MODES = %i(auto one_shot large_file).freeze

    DEFAULT_DELIMITER = '/'
    LARGE_FILE_OPTIONS = {
      max_threads: 4,
      part_size: nil,
    }.freeze

    attr_accessor :bucket, :object, :file_name, :prefix, :mode, :async, :auto_retry, :delimiter
    attr_reader :large_file_opts, :on_success, :on_failure, :file_info

    ##
    # Create a managed upload for this file
    def initialize(bucket: nil, object: nil, file_name: nil, prefix: nil, mode: :auto, async: false, auto_retry: nil, large_file_opts: {}, file_info: {})
      @bucket = bucket
      @object = object
      @mode = mode
      @async = async
      @auto_retry = auto_retry
      @delimiter = DEFAULT_DELIMITER
      @large_file_opts = LARGE_FILE_OPTIONS.merge(large_file_opts)
      @file_info = file_info
      @locked = false
    end

    def background_upload!
      check_locked!
      @async = true
      upload!
    end

    def upload!
      finalize!

      full_name = full_file_name
      file = file_object
      if file.size > large
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

    def finalize!
      check_locked!
      @locked = true

      part_size = large_file_opts[:part_size] || @bucket.account.recommended_part_size
      large_file_opts[:part_size] = [bucket.account.min_part_size, part_size].max
      # Now we're playing for keeps
      self.freeze
    end

    ##
    # Raise an error if we try and modify an upload after starting it
    # @raise [UploadInProgressError]
    def check_locked!
      raise UploadInProgressError, "Upload already in progress. Cannot modify" if @locked
    end

    class UploadFile
      B2_PREFIX = "X-Bz-Info-"

      def initialize(config)
        @config = config
      end

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

    class LargeFile < UploadFile

    end
  end
end
