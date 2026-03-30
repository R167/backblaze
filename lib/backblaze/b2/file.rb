module Backblaze::B2
  class File < Base
    attr_reader :file_name, :bucket_id, :bucket_name
    alias_method :name, :file_name

    def initialize(file_name:, bucket_id:, bucket_name: nil, versions: nil, **file_version_args)
      @file_name = file_name
      @bucket_id = bucket_id
      @bucket_name = bucket_name
      if versions
        @fetched_all = true
        @versions = versions
      else
        @fetched_all = false
        @versions = [FileVersion.new(**file_version_args.merge(file_name: file_name))]
      end
    end

    class << self
      def create(data:, bucket:, name: nil, content_type: 'b2/x-auto', info: {})
        raise ArgumentError, 'data must not be nil' if data.nil?

        bucket_id, bucket_name = resolve_bucket(bucket)
        upload_url = case bucket
                     when Bucket then bucket.upload_url
                     else Bucket.upload_url(bucket_id: bucket_id)
                     end

        data, name, tempfile = prepare_data(data, name)

        begin
          response = perform_upload(upload_url, data, name, content_type, info)
        ensure
          tempfile.close! if tempfile
        end

        params = {
          file_name: response['fileName'],
          bucket_id: response['bucketId'],
          bucket_name: bucket_name,
          size: response['contentLength'],
          file_id: response['fileId'],
          upload_timestamp: Time.now.to_i * 1000,
          action: 'upload'
        }

        File.new(**params)
      end

      # Server-side copy of a file.
      # @param [String] source_file_id the file ID to copy from
      # @param [String] file_name the destination file name
      # @param [String, nil] destination_bucket_id target bucket (same bucket if nil)
      # @param [String] content_type content type for the new file
      # @return [Backblaze::B2::File]
      def copy(source_file_id:, file_name:, destination_bucket_id: nil, content_type: 'b2/x-auto')
        body = {
          sourceFileId: source_file_id,
          fileName: file_name,
          contentType: content_type
        }
        body[:destinationBucketId] = destination_bucket_id if destination_bucket_id

        response = post('/b2_copy_file', body: body.to_json)
        raise Backblaze::FileError.new(response) unless response.code == 200

        params = {
          file_name: response['fileName'],
          bucket_id: response['bucketId'],
          size: response['contentLength'],
          file_id: response['fileId'],
          upload_timestamp: response['uploadTimestamp'] || Time.now.to_i * 1000,
          action: response['action'] || 'copy'
        }

        File.new(**params)
      end

      private

      def resolve_bucket(bucket)
        case bucket
        when Bucket
          [bucket.id, bucket.name]
        when String
          [bucket, nil]
        else
          raise ArgumentError, 'bucket must be a Bucket or bucket ID string'
        end
      end

      def prepare_data(data, name)
        tempfile = nil

        case data
        when String
          data.force_encoding('ASCII-8BIT')
          raise ArgumentError, 'Must provide a file name for string data' if name.nil?
        when ::File, Tempfile
          data.binmode
          data.rewind
          if name.nil?
            raise ArgumentError, 'Must provide a file name with Tempfiles' if data.is_a? Tempfile
            name = ::File.basename(data)
          end
        else
          raise ArgumentError, 'Must provide a file name with streams' if name.nil?
          if data.respond_to?(:read)
            tempfile = Tempfile.new(name)
            tempfile.binmode
            IO.copy_stream(data, tempfile)
            data = tempfile
            data.rewind
          else
            raise ArgumentError, 'Unsuitable data type — must be a String, File, Tempfile, or IO-like object'
          end
        end

        [data, name, tempfile]
      end

      def perform_upload(upload_url, data, name, content_type, info)
        uri = URI(upload_url[:url])
        req = Net::HTTP::Post.new(uri)

        req.add_field("Authorization", upload_url[:token])
        req.add_field("X-Bz-File-Name", b2_encode_file_name(name))
        req.add_field("Content-Type", content_type)
        req.add_field("Content-Length", data.size)

        digest = Digest::SHA1.new
        if data.is_a? String
          digest.update(data)
          req.body = data
        else
          digest.file(data)
          data.rewind
          req.body_stream = data
        end

        req.add_field("X-Bz-Content-Sha1", digest)

        info.first(10).each do |key, value|
          req.add_field("X-Bz-Info-#{b2_encode_file_name(key)}", value)
        end

        http = Net::HTTP.new(req.uri.host, req.uri.port)
        http.use_ssl = (req.uri.scheme == 'https')
        res = http.start { |conn| conn.request(req) }

        response = JSON.parse(res.body)
        raise Backblaze::FileError.new(response) unless res.code.to_i == 200
        response
      end
    end

    def versions
      unless @fetched_all
        @versions = file_versions(bucket_id: @bucket_id, limit: -1, double_check_server: false, file_name: file_name)
        @fetched_all = true
      end
      @versions
    end

    # Build the download-by-name URL
    # @param [Bucket, String, nil] bucket the bucket name or object. Uses stored bucket_name if nil.
    # @return [String]
    def download_url(bucket: nil)
      resolved = bucket ? (bucket.is_a?(Bucket) ? bucket.name : bucket) : @bucket_name
      raise ArgumentError, "No bucket name available — pass bucket: or create file from a Bucket" unless resolved
      "#{Backblaze::B2.download_url}/file/#{resolved}/#{file_name}"
    end

    # Download the file content
    # @param [Bucket, String, nil] bucket the bucket name or object. Uses stored bucket_name if nil.
    # @return [String] the file content
    def download(bucket: nil)
      url = download_url(bucket: bucket)
      response = HTTParty.get(url, headers: {'Authorization' => Backblaze::B2.token})
      raise Backblaze::FileError.new(response) unless response.code == 200
      response.body
    end

    def file_id_download_url
      latest.download_url
    end

    def latest
      @versions.first
    end

    def destroy!(thread_count: 4)
      versions
      thread_count = @versions.length if thread_count > @versions.length || thread_count < 1
      lock = Mutex.new
      errors = []
      threads = []
      thread_count.times do
        threads << Thread.new do
          version = nil
          loop do
            lock.synchronize { version = @versions.pop }
            break if version.nil?
            begin
              version.destroy!
            rescue Backblaze::FileError => e
              lock.synchronize { errors << e }
            end
          end
        end
      end
      threads.map(&:join)
      @destroyed = true
      raise Backblaze::DestroyErrors.new(errors) if errors.any?
    end

    # @return [Boolean] whether this file has been destroyed locally
    def destroyed?
      !!@destroyed
    end

    # @deprecated Use {#destroyed?} instead
    def exists?
      !destroyed?
    end

    # Hide this file so it doesn't show up in b2_list_file_names
    # @raise [Backblaze::FileError] if the file cannot be hidden
    # @return [Backblaze::B2::FileVersion] the hide marker version
    def hide
      response = post('/b2_hide_file', body: {
        bucketId: @bucket_id,
        fileName: file_name
      }.to_json)
      raise Backblaze::FileError.new(response) unless response.code == 200
      FileVersion.new(**response_to_hash(response))
    end

    def method_missing(m, *args, &block)
      if latest.respond_to?(m)
        latest.send(m, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(m, include_private = false)
      latest.respond_to?(m) || super
    end
  end
end
