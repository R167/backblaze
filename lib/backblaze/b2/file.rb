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

    def [](version)
      versions[version]
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
