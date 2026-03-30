module Backblaze::B2
  class FileVersion < Base
    attr_reader :file_id, :size, :action, :upload_timestamp, :file_name

    def initialize(file_id:, size:, upload_timestamp:, action:, file_name:, **_)
      @file_id = file_id
      @size = size
      @action = action
      @file_name = file_name
      @upload_timestamp = Time.at(upload_timestamp / 1000.0)
    end

    def get_info
      unless defined?(@get_info)
        response = post('/b2_get_file_info', body: {fileId: file_id}.to_json)
        raise Backblaze::FileError.new(response) unless response.code == 200

        @get_info = response_to_hash(response)
      end
      @get_info
    end

    def download_url
      "#{Backblaze::B2.download_url}#{Backblaze::B2.api_path}b2_download_file_by_id?fileId=#{file_id}"
    end

    # Download the content of this specific file version
    # @return [String] the file content
    def download
      response = HTTParty.get(download_url, headers: {'Authorization' => Backblaze::B2.token})
      raise Backblaze::FileError.new(response) unless response.code == 200
      response.body
    end

    def destroy!
      response = post('/b2_delete_file_version', body: {fileName: file_name, fileId: file_id}.to_json)
      raise Backblaze::FileError.new(response) unless response.code == 200
      @destroyed = true
    end

    # @return [Boolean] whether this version has been destroyed locally
    def destroyed?
      !!@destroyed
    end

    # @deprecated Use {#destroyed?} instead
    def exists?
      !destroyed?
    end

    class << self
      # Get file info by file ID without needing an existing instance
      # @param [String] file_id the file ID
      # @raise [Backblaze::FileError] if the file info cannot be retrieved
      # @return [Hash] the file info
      def get_info(file_id:)
        response = post('/b2_get_file_info', body: {fileId: file_id}.to_json)
        raise Backblaze::FileError.new(response) unless response.code == 200
        response_to_hash(response)
      end
    end
  end
end
