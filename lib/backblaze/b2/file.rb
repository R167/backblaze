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
      def create(data:, name: nil, base_name: '', content_type: 'b2/x-auto', bucket: nil, upload_url: nil)
        raise ArgumentError.new('data must not be nil') if data.nil?

        if upload_url.nil?
          case bucket
          when String
            upload_url = Bucket.upload_url(bucket)
          when Bucket
            upload_url = bucket.upload_url
          else
            raise ArgumentError.new('Either provide an upload_url of bucket')
          end
        end

        case data
        when String
          data.force_encoding('ASCII-8BIT')
          raise ArgumentError.new('Must provide a file name for data') if name.nil?
        when ::File, Tempfile
          data.binmode
          data.rewind
          if name.nil?
            raise ArgumentError.new('Must provide a file name with Tempfiles') if data.is_a? Tempfile
            name = ::File.basename(data)
          end
        else
          if data.respond_to?(:read)
            Tempfile
          else
            raise ArgumentError.new('Unsuitable data type. Please read the docs.')
          end
        end

        uri = URI.(upload_url)
        req = Net::HTTP::Post.new(uri)

        req.add_field("Authorization","#{upload_authorization_token}")
        req.add_field("X-Bz-File-Name","#{file_name}")
        req.add_field("Content-Type","#{content_type}")
        req.add_field("X-Bz-Content-Sha1","#{sha1}")
        req.add_field("Content-Length",File.size(local_file))
        req.body = File.read(local_file)
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
