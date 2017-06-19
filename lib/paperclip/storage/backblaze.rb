module Paperclip
  module Storage
    module Backblaze
      def self.extended base
        base.instance_eval do
          login
          unless @options[:url].match(/\Ab2.*url\z/)
            @options[:url] = ":b2_path_url".freeze
          end
        end

        Paperclip.interpolates(:b2_path_url) do |attachment, style|
          "#{attachment.b2_protocol(style, true)}//#{attachment.b2_host_name}/#{attachment.b2_bucket_name}/#{attachment.path(style).sub(%r{\A/}, '')}"
        end unless Paperclip::Interpolations.respond_to? :b2_path_url
      end

      def b2_protocol(style, with_colon = true)
        with_colon ? "https:" : "https"
      end

      def b2_host_name
        "f001.backblazeb2.com/file"
      end

      def b2_credentials(filename = @options[:b2_credentials])
        unless @b2_credentials
          require 'psych'
          File.open(filename, 'r') do |f|
            @b2_credentials = Psych.load(f.read).symbolize_keys
          end
        end
        @b2_credentials
      end

      def login
        return if ::Backblaze::B2.token
        creds = b2_credentials
        ::Backblaze::B2.login(account_id: creds[:account_id], application_key: creds[:application_key])
      end

      def b2_bucket
        @b2_bucket ||= ::Backblaze::B2::Bucket.get_bucket(name: @options[:b2_bucket])
      end

      def b2_bucket_name
        b2_bucket.bucket_name
      end

      def exists?(style = default_style)
        !!get_file(filename: path(style).sub(%r{\A/}, ""))
      end

      def get_file(filename:)
        b2_bucket.file_names(first_file: filename, limit: 1).find do |f|
          f.file_name == filename
        end
      end

      def flush_writes
        @queued_for_write.each do |style, file|
          base_name = ::File.dirname(path(style)).sub(%{\A/}, "")
          name = ::File.basename(path(style))
          ::Backblaze::B2::File.create data: file, bucket: b2_bucket, name: name, base_name: base_name
        end
        @queued_for_write = {}
      end

      def flush_deletes
        @queued_for_delete.each do |path|
          if file = get_file(filename: path.sub(%r{\A/}, ''))
            file.destroy!
          end
        end
        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path)
        ::File.open(local_dest_path, 'wb') do |local_file|
          file = get_file(filename: path(style).sub(%r{\A/}, ''))
          body = file.get(file.latest.download_url, parse: :plain)
          local_file.write(body)
        end
      end

    end # module Backblaze
  end # module Storage
end # module Paperclip
