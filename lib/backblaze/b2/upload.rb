# frozen_string_literal: true

require "net/http"
require "tempfile"
require "stringio"
require "digest"
require "multi_json"

module Backblaze::B2
  ##
  # Manages uploading a file.
  #
  # Several modes of uploading are supported. The simplest case just passing in the api and letting everything
  # be handled "magically"
  class Upload
    Config = Struct.new(:tmp)

    MODES = %i[auto one_shot large_file].freeze

    DEFAULT_DELIMITER = "/"
    LARGE_FILE_OPTIONS = {
      max_threads: 4,
      part_size: nil
    }.freeze

    # @return [Bucket]
    attr_accessor :bucket
    attr_accessor :object, :file_name, :prefix, :mode, :async, :auto_retry, :delimiter, :content_type
    attr_reader :large_file_opts, :file_info

    ##
    # Create a managed upload for this file
    def initialize(bucket: nil, object: nil, file_name: nil, content_type: "b2/x-auto", prefix: nil, mode: :auto, async: false, auto_retry: nil, large_file_opts: {}, file_info: {})
      @bucket = bucket
      @object = object
      @mode = mode
      @async = async
      @auto_retry = auto_retry
      @delimiter = DEFAULT_DELIMITER
      @large_file_opts = LARGE_FILE_OPTIONS.merge(large_file_opts)
      @file_info = file_info
      @locked = false
      @content_type = content_type
    end

    def background_upload!
      check_locked!
      @async = true
      upload!
    end

    def upload!
      finalize!

      file = file_object.binmode

      upload = if (file.size > large_file_opts[:min_part_size] && mode == :large_file) ||
          (file.size > large_file_opts.recommended_part_size && mode == :auto)

        LargeFile.new(config)
      else
        UploadFile.new(config)
      end

      upload.upload(file)
    end

    def valid?
      !!(file_name && !file_name.empty? && object && MODES.include?(mode))
    end

    # @return [String] the full file name
    def full_file_name
      if prefix
        "#{prefix}#{delimiter}#{file_name}"
      else
        file_name
      end
    end

    private

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
      freeze
    end

    ##
    # Raise an error if we try and modify an upload after starting it
    # @raise [UploadInProgressError]
    def check_locked!
      raise UploadInProgressError, "Upload already in progress. Cannot modify" if @locked
    end

    class UploadFile
      B2_PREFIX = "X-Bz-Info-"
      # 64 kB
      BLOCK_SIZE = 64 * 1024

      ##
      # @param [Upload] config
      def initialize(config)
        @config = config
      end

      ##
      # @param [File, Tempfile] file
      def upload(file)
        upload_auth = config.bucket.upload_url

        headers = {
          "X-Bz-File-Name" => config.full_file_name,
          "Content-Type" => config.content_type
        }

        b2_headers = config.file_info.merge({})

        response = upload_part(file, file.size, auth: upload_auth[:auth], url: upload_auth[:url], headers: headers, b2_headers: b2_headers)

        FileVersion.new(config.bucket.account, bucket: config.bucket, attrs: response)
      end

      protected

      # @return [Upload]
      attr_reader :config

      ##
      # @return [Hash]
      # @raise [ApiError] on failed upload
      def upload_part(file, size, auth:, url:, headers: {}, b2_headers: {})
        b2_headers.transform_keys! { |key| "#{B2_PREFIX}#{key}" }
        headers = headers.merge(b2_headers, {
          "Content-Length" => size, "User-Agent" => Api::USER_AGENT, "X-Bz-Content-Sha1" => file_digest(file, size)
        })
        uri = URI(url)

        request = Net::HTTP::Post.new(uri)
        headers.each do |header, value|
          request[header] = value
        end

        response = HTTP.headers(**headers).auth(auth).post(url, body: file)
        if file.respond_to?(:unlink)
          file.unlink
        end
        file.close

        if response.status.success?
          # noinspection RubyYardReturnMatch
          MultiJson.load(response.body.to_s)
        else
          raise api_error(response)
        end
      end

      ##
      # Compute the SHA1 of the file. Properly handles starting at an offset and only reading `size` bytes
      # @param [File] file file to digest (at an offset)
      # @param [Integer] size number of bytes to digest
      # @return [String] Hex sha1 hexdigest
      def file_digest(file, size)
        return_pos = file.pos
        buffer = String.new(capacity: BLOCK_SIZE)
        digest = Digest::SHA1.new

        bytes_read = 0

        while bytes_read < size
          # Make sure we don't read more than we're supposed to
          read_bytes = [BLOCK_SIZE, size - bytes_read].min
          digest << file.read(read_bytes, buffer)
          bytes_read += buffer.length
        end

        file.seek(return_pos)
        digest.hexdigest
      end
    end

    class LargeFile < UploadFile
      def upload
      end
    end
  end
end
