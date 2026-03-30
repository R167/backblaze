module Backblaze::B2
  class Base
    include HTTParty
    include Backblaze::Utils

    format :json

    [:get, :head, :post, :put].each do |req|
      define_method(req) do |path, options={}, &block|
        self.class.send(req, path, options, &block)
      end
    end

    protected

    def file_versions(bucket_id:, limit:, double_check_server:, file_name: nil, &block)
      retrieve_count = (double_check_server ? 0 : -1)
      files = file_list(bucket_id: bucket_id, limit: limit, retrieved: retrieve_count, file_name: file_name, first_file: nil, start_field: 'startFileId'.freeze)

      files.map! do |f|
        block.nil? ? Backblaze::B2::FileVersion.new(**f) : block.call(f)
      end
      files.compact
    end

    def file_list(limit:, retrieved:, first_file:, start_field:, bucket_id:, file_name: nil, first: true)
      params = {'bucketId' => bucket_id}
      if limit == -1
        params['maxFileCount'] = 1000
      elsif limit > 1000
        params['maxFileCount'] = 1000
      elsif limit > 0
        params['maxFileCount'] = limit
      else
        return []
      end
      if first_file.nil?
        if file_name && start_field == 'startFileId' && first
          params['startFileName'] = file_name
        end
      else
        params[start_field] = first_file
      end

      response = post("/b2_list_file_#{start_field == 'startFileName' ? 'names' : 'versions'}", body: params.to_json)

      raise Backblaze::FileError.new(response) unless response.code == 200

      files = response['files']
      halt = false
      files.map! do |f|
        if halt
          nil
        else
          ret = response_to_hash(f)
          halt = true if file_name && file_name != ret[:file_name]
          halt ? nil : ret
        end
      end.compact!

      retrieved = retrieved + files.size if retrieved >= 0
      if limit > 0
        limit = limit - (retrieved >= 0 ? files.size : 1000)
        limit = 0 if limit < 0
      end

      next_item = response[start_field.sub('start', 'next')]

      if (limit > 0 || limit == -1) && !!next_item && !halt
        files.concat file_list(
          first_file: next_item,
          limit: limit,
          retrieved: retrieved,
          start_field: start_field,
          bucket_id: bucket_id,
          first: false
        )
      else
        files
      end
    end
  end
end
