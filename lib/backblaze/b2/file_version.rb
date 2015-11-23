module Backblaze::B2
  class FileVersion < Base
    attr_reader :file_id, :size, :action, :upload_timestamp, :file_name

    def initialize(file_id:, size:, upload_timestamp:, action:, file_name:)
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

        @get_info = Hash[response.map{|k,v| [Backblaze::Utils.underscore(k).to_sym, v]}]
      end
      @get_info
    end

    def download_url
      "#{Backblaze::B2.download_url}#{Backblaze::B2.api_path}b2_download_file_by_id?fileId=#{file_id}"
    end

    def destroy!
      response = post('/b2_delete_file_version', body: {fileName: file_name, fileId: file_id}.to_json)
      raise Backblaze::FileError.new(response) unless response.code == 200
      @destroyed = true
    end

    def exists?
      !@destroyed
    end
  end
end
