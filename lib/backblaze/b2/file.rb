module Backblaze::B2
  class FileObject < Base
    MEGABYTE = 1_000_000

    def initialize(file_name:, bucket_id:, versions: nil, **file_version_args)
      @file_name = file_name
      @bucket_id = bucket_id
      if versions
        @fetched_all = true
        @versions = versions
      else
        @fetched_all = false
        @versions = [FileVersion.new(file_version_args.merge(file_name: file_name, bucket_id: bucket_id))]
      end
    end

    class << self
      ##
      # Upload a file
      # @param [String, File, Tempfile, #read] data data to be uploaded
      #   the data is assumed to be in one of the above formats. A Tempfile, File,
      #   or Object that responds to read is preferred as it can then be uploaded
      #   as a stream rather than as binary data handled by ruby. Any String passed
      #   will be interpretted as ASCII-8BIT and then sent as the body of the request.
      # @param [Backblaze::B2::Bucket, String] bucket the bucket to upload this file to
      # @raise [Backblaze::BucketError] unable to create the specified bucket
      def create(data:, bucket:, name: nil, base_name: '', content_type: 'b2/x-auto', info: {}, chunk_size: 100)
        raise ArgumentError.new('data must not be nil') if data.nil?

        if !bucket.is_a?(String) || !bucket.is_a?(Bucket)
          raise ArgumentError.new('You must pass a bucket')
        end

        close_file = false
        case data
        when String
          data.force_encoding('ASCII-8BIT')
          raise ArgumentError.new('Must provide a file name for data') if name.nil?
        when File, Tempfile
          data.binmode
          data.rewind
          if name.nil?
            raise ArgumentError.new('Must provide a file name with Tempfiles') if data.is_a? Tempfile
            name = File.basename(data)
          end
        else
          raise ArgumentError.new('Must provide a file name with streams') if name.nil?
          if data.respond_to?(:read)
            close_file = true
            temp = Tempfile.new(name)
            temp.binmode
            IO.copy_stream(data, temp)
            data = temp
            data.rewind
          else
            raise ArgumentError.new('Unsuitable data type. Please read the docs.')
          end
        end

        file_name = "#{base_name}/#{name}".tr_s('/', '/').sub(/\A\//, '')
        chunk = MEGABYTE * chunk_size

        if file.size > chunk && !data.is_a?(String)
          # UPLOAD LARGE FILE
          start_request = {
            fileName: file_name,
            contentType: content_type,
            fileInfo: info
          }
          if bucket.is_a?(String)
            start_request[:bucketId] = bucket
          else
            start_request[:bucketId] = bucket.bucket_id
          end

          start_parsed = post('/b2_start_large_file', body: start_request.to_json)
          raise Backblaze::FileError.new(start_parsed) unless start_parsed.code == 200

          upload_parsed = post('/b2_get_upload_part_url', body: {fileId: start_parsed[:fileId]}.to_json)
          raise Backblaze::FileError.new(upload_parsed) unless upload_parsed.code == 200

          10_000.times do |part_num|
            temp = Tempfile.new(name)
            temp.binmode
            IO.copy_stream(data, temp, chunk, chunk * part_num)
            data = temp
            data.rewind

            digest = Digest::SHA1.new
            if data.is_a? String
              digest.update(data)
              req.body = data
            else
              digest.file(data)
              data.rewind
              req.body_stream = data
            end

            req.add_field("Authorization", upload_url[:token])
            req.add_field("X-Bz-Part-Number", part_num)
            req.add_field("Content-Length", data.size)
            req.add_field("X-Bz-Content-Sha1", digest)

            http = Net::HTTP.new(req.uri.host, req.uri.port)
            http.use_ssl = (req.uri.scheme == 'https')
            res = http.start {|make| make.request(req)}

            response = JSON.parse(res.body)
          end

        else
          # UPLOAD NORMAL FILE
          if bucket.is_a?(String)
            upload_url = Bucket.upload_url(bucket_id: bucket)
          else
            upload_url = bucket.upload_url
          end

          uri = URI(upload_url[:url])
          req = Net::HTTP::Post.new(uri)

          digest = Digest::SHA1.new
          if data.is_a? String
            digest.update(data)
            req.body = data
          else
            digest.file(data)
            data.rewind
            req.body_stream = data
          end

          req.add_field("Authorization", upload_url[:token])
          req.add_field("X-Bz-File-Name", file_name)
          req.add_field("Content-Type", content_type)
          req.add_field("Content-Length", data.size)
          req.add_field("X-Bz-Content-Sha1", digest)

          info.first(10).map do |key, value|
            req.add_field("X-Bz-Info-#{URI.encode(key)}", value)
          end

          http = Net::HTTP.new(req.uri.host, req.uri.port)
          http.use_ssl = (req.uri.scheme == 'https')
          res = http.start {|make| make.request(req)}

          response = JSON.parse(res.body)

          raise Backblaze::FileError.new(response) unless res.code.to_i == 200

          FileObject.new(Hash[response.map{|k,v| [Backblaze::Utils.underscore(k).to_sym, v]}])
        end
      end
    end

    def file_name
      @file_name
    end
    alias_method :name, :file_name

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
      if errors.any?
        raise Backblaze::DestroyErrors.new(errors)
      end
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
