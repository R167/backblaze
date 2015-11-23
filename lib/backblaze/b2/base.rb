module Backblaze::B2
  class Base
    include HTTParty
    include Backblaze::Utils

    format :json

    # @!method get(path, options={}, &block)
    # Calls the class level equivalent from HTTParty
    # @see http://www.rubydoc.info/github/jnunemaker/httparty/HTTParty/ClassMethods HTTParty::ClassMethods

    # @!method head(path, options={}, &block)
    # (see #get)

    # @!method post(path, options={}, &block)
    # (see #get)

    # @!method put(path, options={}, &block)
    # (see #get)

    [:get, :head, :post, :put].each do |req|
      define_method(req) do |path, options={}, &block|
        self.class.send(req, path, options, &block)
      end
    end

    protected

    def file_versions(bucket_id:, convert:, limit:, double_check_server:, file_name: nil, &block)
      retreive_count = (double_check_server ? 0 : -1)
      files = file_list(bucket_id: bucket_id, limit: limit, retreived: retreive_count, file_name: file_name, first_file: nil, start_field: 'startFileId'.freeze)

      files.map! do |f|
        if block.nil?
          Backblaze::B2::FileVersion.new(f)
        else
          block.call(f)
        end
      end if convert
      files.compact
    end

    def file_list(limit:, retreived:, first_file:, start_field:, bucket_id:, file_name: nil, first: true)
      params = {'bucketId'.freeze => bucket_id}
      if limit == -1
        params['maxFileCount'.freeze] = 1000
      elsif limit > 1000
        params['maxFileCount'.freeze] = 1000
      elsif limit > 0
        params['maxFileCount'.freeze] = limit
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

      p params

      response = post("/b2_list_file_#{start_field == 'startFileName' ? 'names' : 'versions'}", body: params.to_json)

      raise Backblaze::FileError.new(response) unless response.code == 200

      files = response['files'.freeze]
      halt = false
      files.map! do |f|
        if halt
          p f
          nil
        else
          ret = Hash[f.map{|k,v| [Backblaze::Utils.underscore(k).to_sym, v]}]
          p ret
          if file_name && file_name != ret[:file_name]
            halt = true
          end
          halt ? nil : ret
        end
      end.compact!

      retreived = retreived + files.size if retreived >= 0
      if limit > 0
        limit = limit - (retreived >= 0 ? files.size : 1000)
        limit = 0 if limit < 0
      end

      next_item = response[start_field.sub('start'.freeze, 'next'.freeze)]

      if (limit > 0 || limit == -1) && !!next_item && !halt
        files.concat file_list(
          first_file: next_item,
          limit: limit,
          retreived: retreived,
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
