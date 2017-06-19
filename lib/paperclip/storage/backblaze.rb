module Paperclip
  module Storage
    # Defines a adapter to use store Paperclip attachments to Backblaze B2
    # Cloud Storage, which is similar to Amazon's S3 service.
    #
    # This allows you to use has_attached_file in your models
    # with :storage => :backblaze.
    #
    # Some required options include:
    #
    #   :storage - This should be set to :backblaze in order to use this
    #     storage adapter.
    #
    #   :b2_credentials - This should point to a YAML file containing your B2
    #     account ID and application key. The contents should look something
    #     like:
    #
    #     account_id: 123456789abc
    #     application_key: 0123456789abcdef0123456789abcdef0123456789
    #
    #   :b2_bucket - This should name the bucket to save files to.
    #
    # So for example, a model might be configured something like this:
    #
    #   class Note < ApplicationRecord
    #     has_attached_file :image,
    #       storage: :backblaze,
    #       b2_credentials: Rails.root.join('config/b2.yml'),
    #       b2_bucket: 'bucket_for_my_app'
    #     ...
    #
    module Backblaze
      def self.extended base
        base.instance_eval do
          login
          unless @options[:url].match(/\Ab2.*url\z/)
            @options[:url] = ":b2_path_url".freeze
          end
        end

        Paperclip.interpolates(:b2_path_url) do |attachment, style|
          "#{::Backblaze::B2.download_url}/file/#{attachment.b2_bucket_name}/#{attachment.path(style).sub(%r{\A/}, '')}"
        end unless Paperclip::Interpolations.respond_to? :b2_path_url
      end

      # Fetch the credentials from the config file, if it hasn't already been
      # loaded.
      #
      # filename : String - path to the YAML config file containing the
      # Backblaze B2 credentials. Here is example contents of what one
      # may look like:
      #
      #   account_id: 123456789abc
      #   application_key: 0123456789abcdef0123456789abcdef0123456789
      #
      # Returns a Hash containing the parsed credentials.
      def b2_credentials(filename = @options[:b2_credentials])
        unless @b2_credentials
          require 'psych'
          File.open(filename, 'r') do |f|
            @b2_credentials = Psych.load(f.read).symbolize_keys
          end
        end
        @b2_credentials
      end

      # Authenticate with Backblaze with the account ID and secret key. This
      # also caches several variables from the response related to the API, so
      # it is important that it is executed at the very beginning.
      def login
        return if ::Backblaze::B2.token
        creds = b2_credentials
        ::Backblaze::B2.login(account_id: creds[:account_id], application_key: creds[:application_key])
      end

      # Return the Backblaze::B2::Bucket object representing the bucket
      # specified by the required options[:b2_bucket].
      def b2_bucket
        @b2_bucket ||= ::Backblaze::B2::Bucket.get_bucket(name: @options[:b2_bucket])
      end

      # Return the specified bucket name as a String.
      def b2_bucket_name
        b2_bucket.bucket_name
      end

      # Return whether this attachment exists in the bucket.
      def exists?(style = default_style)
        !!get_file(filename: get_path(style))
      end

      # Return a Backblaze::B2::File object representing the file named in the
      # filename keyword, if it exists.
      def get_file(filename:)
        b2_bucket.file_names(first_file: filename, limit: 1).find do |f|
          f.file_name == filename
        end
      end

      # Return this attachment's bucket file path as a String.
      def get_path(style = default_style)
        path(style).sub(%r{\A/}, '')
      end

      # (Internal) Used by Paperclip to upload local files to storage.
      def flush_writes
        @queued_for_write.each do |style, file|
          base_name = ::File.dirname(get_path(style))
          name = ::File.basename(get_path(style))
          ::Backblaze::B2::File.create data: file, bucket: b2_bucket, name: name, base_name: base_name
        end
        @queued_for_write = {}
      end

      # (Internal) Used by Paperclip to remove remote files from storage.
      def flush_deletes
        @queued_for_delete.each do |path|
          if file = get_file(filename: path.sub(%r{\A/}, ''))
            file.destroy!
          end
        end
        @queued_for_delete = []
      end

      # (Internal)
      def copy_to_local_file(style, local_dest_path)
        ::File.open(local_dest_path, 'wb') do |local_file|
          file = get_file(filename: get_path(style))
          body = file.get(file.latest.download_url, parse: :plain)
          local_file.write(body)
        end
      end

    end # module Backblaze
  end # module Storage
end # module Paperclip
