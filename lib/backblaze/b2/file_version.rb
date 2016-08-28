module Backblaze::B2
  class FileVersion < Base
    attr_reader :file_id, :content_length, :action, :upload_timestamp, :file_name

    def initialize(file_id:, content_length:, upload_timestamp:, action:, file_name:, **options)
      @file_id = file_id
      @content_length = content_length
      @action = action
      @file_name = file_name
      @upload_timestamp = Time.at(upload_timestamp / 1000.0)
      @other = options
    end

    ##
    # Gets the info for the particular file version
    # @return [Hash] the file info
    # @see https://www.backblaze.com/b2/docs/b2_get_file_info.html Backblaze B2 b2_get_file_info request
    def get_info
      unless defined?(@get_info)
        response = post('/b2_get_file_info', body: {fileId: file_id}.to_json)
        raise Backblaze::FileError.new(response) unless response.code == 200

        @get_info = Hash[response.map{|k,v| [Backblaze::Utils.underscore(k).to_sym, v]}]
      end
      @get_info
    end

    def download_url
      "#{Backblaze::B2.download_url}#{Backblaze::B2.api_path}b2_download_file_by_id?fileId=#{file_id}"
    end

    alias_method :size, :content_length

    def destroy!
      response = post('/b2_delete_file_version', body: {fileName: file_name, fileId: file_id}.to_json)
      raise Backblaze::FileError.new(response) unless response.code == 200
      @destroyed = true
    end

    def exists?
      !@destroyed
    end

    def responds_to?(sym, include_private = false)
      @other.has_key?(sym) || super(sym, include_private)
    end

    def method_missing(method, *args, &block)
      if responds_to?(method)
        @other[method]
      else
        super(method, *args, &block)
      end
    end
  end
end
