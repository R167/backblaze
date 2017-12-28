module Backblaze::B2
  class File < Base
    def initialize(file_name:, bucket_id:, versions: nil, **file_version_args)
      @file_name = file_name
      @bucket_id = bucket_id
      if versions
        @fetched_all = true
        @versions = versions
      else
        @fetched_all = false
        @versions = [FileVersion.new(file_version_args.merge(file_name: file_name))]
      end
    end

    class << self
      def create(data:, bucket:, name: nil, base_name: '', content_type: 'b2/x-auto', info: {})
        raise ArgumentError, 'data must not be nil' if data.nil?

        case bucket
        when String
          upload_url = Bucket.upload_url(bucket_id: bucket)
        when Bucket
          upload_url = bucket.upload_url
        else
          raise ArgumentError, 'You must pass a bucket'
        end

        case data
        when String
          data.force_encoding('ASCII-8BIT')
          raise ArgumentError, 'Must provide a file name for data' if name.nil?
        when ::File, Tempfile, ::Paperclip::UploadedFileAdapter
          data.binmode
          data.rewind
          if name.nil?
            raise ArgumentError, 'Must provide a file name with Tempfiles' if data.is_a? Tempfile
            name = ::File.basename(data)
          end
        else
          raise ArgumentError, 'Must provide a file name with streams' if name.nil?
          if data.respond_to?(:read)
            temp = Tempfile.new(name)
            temp.binmode
            IO.copy_stream(data, temp)
            data = temp
            data.rewind
          else
            raise ArgumentError, 'Unsuitable data type. Please read the docs.'
          end
        end

        uri = URI(upload_url[:url])
        req = Net::HTTP::Post.new(uri)

        req.add_field('Authorization', upload_url[:token])
        req.add_field('X-Bz-File-Name', "#{base_name}/#{name}".tr_s('/', '/').sub(/\A\//, ''))
        req.add_field('Content-Type', content_type)
        req.add_field('Content-Length', data.size)

        digest = Digest::SHA1.new
        if data.is_a? String
          digest.update(data)
          req.body = data
        elsif data.is_a? ::Paperclip::UploadedFileAdapter
          digest.file(data.path)
          data.rewind
          req.body_stream = data
        else
          digest.file(data)
          data.rewind
          req.body_stream = data
        end

        req.add_field('X-Bz-Content-Sha1', digest)

        info.first(10).map do |key, value|
          encoded_key = URI.encode_www_form_component(key)
          req.add_field("X-Bz-Info-#{encoded_key}", value)
        end

        http = Net::HTTP.new(req.uri.host, req.uri.port)
        http.use_ssl = (req.uri.scheme == 'https')
        res = http.start { |make| make.request(req) }

        response = JSON.parse(res.body)

        raise Backblaze::FileError, response unless res.code.to_i == 200

        params = {
          file_name: response['fileName'],
          bucket_id: response['bucketId'],
          size: response['contentLength'],
          file_id: response['fileId'],
          upload_timestamp: Time.now.to_i * 1000,
          content_length: data.size,
          content_type: content_type,
          content_sha1: digest,
          action: 'upload'
        }

        File.new(params)
      end
    end

    attr_reader :file_name
    alias name file_name

    def versions
      unless @fetched_all
        @versions = file_versions(bucket_id: @bucket_id, convert: true, limit: -1, double_check_server: false, file_name: file_name)
        @fetched_all = true
      end
      @versions
    end

    def download_url(bucket:)
      "#{Backblaze::B2.download_url}/file/#{bucket.is_a?(Bucket) ? bucket.name : bucket}/#{file_name}"
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
      raise Backblaze::DestroyErrors, errors if errors.any?
    end

    def exists?
      !@destroyed
    end

    def method_missing(m, *args, &block)
      if latest.respond_to?(m)
        latest.send(m, *args, &block)
      else
        super
      end
    end

    def respond_to?(m)
      if latest.respond_to?(m)
        true
      else
        super
      end
    end
  end
end
