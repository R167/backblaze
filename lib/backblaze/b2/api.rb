# frozen_string_literal: true

require "http"
require "uri"
require "net/http"
require "net/http/persistent"

require "backblaze/version"
require "backblaze/b2/exceptions"
require "backblaze/b2/util"

module Backblaze::B2
  ##
  # Minimal wrapper around the B2 API to handle basic things like connections,
  # urls, etc.
  #
  # @todo Measures should be taken to ensure this class is threadsafe
  class Api
    include Util

    API_VERSION = "v2"
    AUTH_ENDPOINT = "https://api.backblazeb2.com/b2api/#{API_VERSION}/b2_authorize_account"

    # One day in seconds. Duration tokens are valid for
    ONE_DAY = 24 * 60 * 60

    KEY_CAPABILITIES = %w[listKeys writeKeys deleteKeys].freeze
    BUCKET_CAPABILITIES = %w[listBuckets writeBuckets deleteBuckets].freeze
    FILE_CAPABILITIES = %w[listFiles readFiles shareFiles writeFiles deleteFiles].freeze
    CAPABILITIES = (KEY_CAPABILITIES + BUCKET_CAPABILITIES + FILE_CAPABILITIES).freeze

    # Valid download duration authorization is between one second and one week
    VALID_DOWNLOAD_DURATION = (1..(7 * ONE_DAY)).freeze

    attr_reader :api_url, :download_url, :account_id
    # @return [Integer] Byte size of upload part
    attr_reader :min_part_size, :recommended_part_size

    ##
    # Helper for accessing B2 API operations. This keeps track of minimal state, persisting the account_id and credentials
    # for reauthorization.
    # @param application_key_id Application Key ID for authenticating with Backblaze
    # @param application_key Application Key for authenticating with Backblaze
    # @param [Boolean] login login on object creation
    def initialize(application_key_id, application_key, login: true)
      @app_key_id = application_key_id
      @app_key_secret = application_key
      # Ruby 2.4 compatibility
      @mutex = defined?(Mutex) ? Mutex.new : Thread::Mutex.new
      @connection = create_connection_pool
      @pid = Process.pid
      login! if login
    end

    def login!
      connection.override_headers["User-Agent"] = Backblaze::USER_AGENT
      connection.headers["Accept"] = "application/json"
      connection.idle_timeout = 5
      authorize!
    end

    def logout!
      connection&.shutdown
      connection.headers.clear
    end

    ##
    # Helper for getting access to the auth token needed by nearly all requests
    # @param refresh force a reauthorization of credentials
    # @return an auth_token
    def auth_token(refresh = false)
      authorize! if refresh || !@auth_token
      @auth_token
    end

    # @!group Authorization

    ##
    # Used to log in to the B2 API. Returns an authorization token that can be used for account-level operations,
    # and a URL that should be used as the base URL for subsequent API calls.
    # @return [Hash] account attributes
    # @see https://www.backblaze.com/b2/docs/b2_authorize_account.html
    def authorize_account
      response = get_basic_auth(AUTH_ENDPOINT, @app_key_id, @app_key_secret)

      if response.code == "200"
        parse_json(response)
      else
        api_error(response)
      end
    end

    ##
    # Authorize the account and set attributes. Thread safe.
    def authorize!
      @mutex.synchronize do
        data = authorize_account
        @download_url = data["downloadUrl"]
        @api_url = data["apiUrl"]
        @auth_token = data["authorizationToken"]
        @account_id = data["accountId"]
        @min_part_size = data["absoluteMinimumPartSize"]
        @recommended_part_size = data["recommendedPartSize"]

        @connection.headers["Authorization"] = @auth_token
      end
    end

    # @!endgroup
    # @!group B2 API operations

    ##
    # Cancels the upload of a large file, and deletes all of the parts that have been uploaded.
    # @param file_id from {#start_large_file} to cancel
    # @return info about canceled file
    # @see https://www.backblaze.com/b2/docs/b2_cancel_large_file.html
    def cancel_large_file(file_id)
      post_api("b2_cancel_large_file", fileId: file_id)
    end

    ##
    # Creates a new file by copying from an existing file.
    #
    # When copying, you can either just copy everything about the file, or opt to change the content_type and file_info.
    # If you set the content type, then you will use the `REPLACE` directive. Otherwise, `COPY` is the default.
    # @param source_id file id of the source file
    # @param dest_name destination filename (equivalent to uploading a file)
    # @param bucket_id destination bucket for the new file. Defaults to the same as source.
    # @param [String, Range<Integer>] range byte range to copy.
    #   This can be either a string (assumed of form `bytes=start-end` like in a range header)
    #   or it can be a range object.
    # @param content_type mime type of the copied file (will default to source)
    # @param file_info new file info to specify when copying
    # @return file info
    # @see https://www.backblaze.com/b2/docs/b2_copy_file.html
    def copy_file(source_id, dest_name, bucket_id: nil, range: nil, content_type: nil, file_info: nil)
      replace = !content_type.nil?
      request_attributes = {
        sourceFileId: source_id,
        fileName: dest_name,
        destinationBucketId: bucket_id,
        range: construct_range(range),
        metadataDirective: "COPY"
      }
      if replace
        request_attributes.merge!({
          contentType: content_type,
          fileInfo: file_info,
          metadataDirective: "REPLACE"
        })
      end
      post_api("b2_copy_file", request_attributes)
    end

    ##
    # Copies from an existing B2 file, storing it as a part of a large file which has already been
    # started (with {#start_large_file}).
    # @param source_id file id of the source file being copied.
    # @param dest_id file id of the large file the part will belong to
    # @param part_number the part number for this entry in the large file
    # @param range: (see #copy_file)
    # @see https://www.backblaze.com/b2/docs/b2_copy_part.html
    def copy_part(source_id, dest_id, part_number, range: nil)
      request_attributes = {
        sourceFileId: source_id,
        largeFileId: dest_id,
        partNumber: part_number,
        range: construct_range(range)
      }
      post_api("b2_copy_part", request_attributes)
    end

    ##
    # Create a bucket for the current account with the given attributes
    # @param name Bucket name
    # @param visibility Bucket public/private visibility ["allPrivate", "allPublic"]
    # @param info Additional bucket meta data. This is where you can specify
    #   bucket wide `Cache-Control` options
    # @param cors list of cors rules
    # @param lifecycle list of lifecyle rules
    # @return [Hash] bucket creation attributes
    # @see https://www.backblaze.com/b2/docs/lifecycle_rules.html Lifecycle Rules
    # @see https://www.backblaze.com/b2/docs/cors_rules.html CORS Rules
    # @see https://www.backblaze.com/b2/docs/b2_create_bucket.html
    def create_bucket(name, visibility: "allPrivate", info: {}, cors: [], lifecycle: [])
      request_attributes = {
        accountId: account_id,
        bucketName: name,
        bucketType: visibility,
        bucketInfo: info,
        corsRules: cors,
        lifecycleRules: lifecycle
      }
      post_api("b2_create_bucket", request_attributes)
    end

    ##
    # Creates a new application key.
    # @param name New key name (this is for human use only and does not identify the key nor need to be unique)
    # @param [Array] capabilities A list of capabilities for the key. Refer to {CAPABILITIES} for valid values.
    # @param [Integer] expires_in Number of seconds this key is valid for. If specified, must be less than 1_000 days
    #   (in seconds). Default is no expiration.
    # @param bucket_id Restrict the created key to only accessing the specified bucket.
    # @param prefix Restrict the created key to only accessing files that start with `prefix`. If this is specified,
    #   `bucket_id` is required as well.
    # @return Attributes of a new key
    # @see https://www.backblaze.com/b2/docs/b2_create_key.html
    def create_key(name, capabilities, expires_in: nil, bucket_id: nil, prefix: nil)
      request_attributes = {
        accountId: account_id,
        keyName: name,
        capabilities: capabilities,
        validDurationInSeconds: expires_in.to_i,
        bucketId: bucket_id,
        namePrefix: prefix
      }
      post_api("b2_create_key", request_attributes)
    end

    ##
    # Deletes the bucket specified. Only buckets that contain no version of any files can be deleted.
    # @param bucket_id bucket to delete
    # @see https://www.backblaze.com/b2/docs/b2_delete_bucket.html
    def delete_bucket(bucket_id)
      post_api("b2_delete_bucket", accountId: account_id, bucketId: bucket_id)
    end

    ##
    # Deletes one version of a file from B2.
    # @param name name of the file
    # @param file_id version of this file to delete
    # @see https://www.backblaze.com/b2/docs/b2_delete_file_version.html
    def delete_file_version(name, file_id)
      post_api("b2_delete_file_version", fileName: name, fileId: file_id)
    end

    ##
    # Deletes the application key specified.
    # @param key_id id of the application key to delete
    # @see https://www.backblaze.com/b2/docs/b2_delete_key.html
    def delete_key(key_id)
      post_api("b2_delete_key", applicationKeyId: key_id)
    end

    ##
    # Converts the parts that have been uploaded into a single B2 file.
    # @param file_id the file id returned in {#start_large_file}
    # @param [Array<String>] sha1_array list of sha1 for each of the upload parts in order
    # @return large file info
    # @see https://www.backblaze.com/b2/docs/b2_finish_large_file.html
    def finish_large_file(file_id, sha1_array)
      post_api("b2_finish_large_file", fileId: file_id, partSha1Array: sha1_array)
    end

    ##
    # Used to generate an authorization token that can be used to download files with the specified prefix
    # (and other optional headers) from a private B2 bucket for use in download_by_file_name
    #
    # You can specify additional headers that are then set and used during download. A full listing of these
    # can be found in on the full docs page (see below). These can either be specified as additional keyword arguments,
    # or passed as a Hash to `b2_headers:`. Note: the keys are not modified at all so you must exactly specify the keys
    # in camelCase.
    # @param bucket_id bucket where this authorization will be valid
    # @param prefix file name prefix for downloading
    # @param expires_in number of seconds this token is valid for. Can be in the range of 1 second to 1 week
    # @param b2_headers header fields that are forced on download
    # @see https://www.backblaze.com/b2/docs/b2_get_download_authorization.html
    def get_download_authorization(bucket_id, prefix:, expires_in:, b2_headers: {}, **kwargs)
      request_attributes = {
        bucketId: bucket_id,
        fileNamePrefix: prefix,
        validDurationInSeconds: expires_in.clamp(VALID_DOWNLOAD_DURATION)
      }.merge(b2_headers, kwargs)
      post_api("b2_get_download_authorization", request_attributes)
    end

    ##
    # Gets information about one file stored in B2.
    # @param file_id to get info about
    # @see https://www.backblaze.com/b2/docs/b2_get_file_info.html
    def get_file_info(file_id)
      post_api("b2_get_file_info", fileId: file_id)
    end

    ##
    # Gets an URL to use for uploading parts of a large file.
    # @param file_id The ID of the large file whose parts you want to upload
    # @see https://www.backblaze.com/b2/docs/b2_get_upload_part_url.html
    def get_upload_part_url(file_id)
      post_api("b2_get_upload_part_url", fileId: file_id)
    end

    ##
    # Gets a URL to use for uploading files.
    # @param bucket_id The ID of the bucket that you want to upload to
    # @return an uploadUrl and authorizationToken for uploading
    # @see https://www.backblaze.com/b2/docs/b2_get_upload_url.html
    def get_upload_url(bucket_id)
      post_api("b2_get_upload_url", bucketId: bucket_id)
    end

    ##
    # Hides a file so that downloading by name will not find the file, but previous versions of the file are
    # still stored. See [File Versions](https://www.backblaze.com/b2/docs/file_versions.html) about what it means to hide a file.
    # @param bucket_id bucket where the file resides
    # @param file_name name of the file to mark as hidden
    # @see https://www.backblaze.com/b2/docs/b2_hide_file.html
    def hide_file(bucket_id, file_name)
      post_api("b2_hide_file", bucketId: bucket_id, fileName: file_name)
    end

    ##
    # Lists buckets associated with an account, in alphabetical order by bucket name
    #
    # When using an authorization token that is restricted to a bucket, you must include the bucketId or bucketName of
    # that bucket in the request, or the request will be denied.
    # @param bucket_id ID of a specific bucket to list
    # @param bucket_name Name of a specific bucket to list
    # @param [Array] types types of buckets to list. Must be only of `[:all, :allPublic, :allPrivate, :snapshot]`.
    #   Default is to list all.
    # @see https://www.backblaze.com/b2/docs/b2_list_buckets.html
    def list_buckets(bucket_id: nil, bucket_name: nil, types: nil)
      post_api("b2_list_buckets", accountId: account_id, bucketId: bucket_id, bucketName: bucket_name, bucketTypes: types).tap do |data|
        data[:iter] = {key: "buckets", start_at: nil}
      end
    end

    ##
    # Lists the names of all files in a bucket, starting at a given name
    #
    # Will return a list of files and the next file name to start at. If nextFileName is nil, then there are no more files
    # to iterate through in the bucket.
    #
    # @example Iterate over all files and print names
    #   api = ...
    #   my_bucket = '<some-bucket-id>'
    #   MAX_FILES = 1000
    #   last_file = ''
    #   while !last_file.nil?
    #     data = api.list_file_names(my_bucket, start_at: last_file, count: MAX_FILES)
    #     last_file = data[:iter][:start_at]
    #     data['files'].each do |file|
    #       puts file['fileName']
    #     end
    #   end
    #
    # @param bucket_id The bucket to look for files in.
    # @param start_at Iteration information
    # @option start_at :name (nil) The first file name to return. If there is a file with this name, it will be returned in the list.
    #   If not, the first file name after this the first one after this name.
    # @param [Integer<0..1000>] count The maximum number of results to return from this call. The default value is 100,
    #   and the maximum is 10_000. Passing in 0 means to use the default of 100. Every multiple of 1_000 is considered
    #   a separate billable Class C transaction
    # @param prefix Files returned will be limited to those with the given prefix. Defaults to empty string, which matches all files.
    # @param delimiter Files returned will be limited to those within the top folder, or any one subfolder, split on this char.
    # @return Hash `{'files' => [...{file info}...], 'nextFileName' => next_file_name, iter: {iteration-data}}`
    # @see https://www.backblaze.com/b2/docs/b2_list_file_names.html
    def list_file_names(bucket_id, start_at: {name: nil}, count: 0, prefix: "", delimiter: nil)
      start_name = start_at.is_a?(Hash) ? start_at[:name] : start_at
      request_attributes = {
        bucketId: bucket_id,
        startFileName: start_name,
        maxFileCount: count,
        prefix: prefix,
        delimiter: delimiter
      }
      post_api("b2_list_file_names", request_attributes).tap do |data|
        data[:iter] = {key: "files", start_at: {name: data["nextFileName"]}, stop: data["nextFileName"].nil?}
      end
    end

    ##
    # Lists all of the versions of all of the files contained in one bucket, in alphabetical order by file name, and by
    # reverse of date/time uploaded for versions of files with the same name.
    # @param (see #list_file_names)
    # @option (see #list_file_names)
    # @option start_at :id (nil) File ID to start at when iterating (start_at[:name] is also required if this is set)
    # @return Hash of `files`, `nextFileName`, and `nextFileId` (see {#list_file_names})
    def list_file_versions(bucket_id, start_at: {id: nil, name: nil}, count: nil, prefix: "", delimiter: nil)
      start_name = start_at[:name]
      start_id = start_at[:id]
      request_attributes = {
        bucketId: bucket_id,
        startFileName: start_name,
        startFileId: start_id,
        maxFileCount: count,
        prefix: prefix,
        delimiter: delimiter
      }
      post_api("b2_list_file_versions", request_attributes).tap do |data|
        stop = data["nextFileName"].nil? && data["nextFileId"].nil?
        data[:iter] = {key: "files", start_at: {name: data["nextFileName"], id: data["nextFileId"]}, stop: stop}
      end
    end

    ##
    # Lists application keys associated with the account.
    # @param start_at The first key to return. Used for iterating, similar to `start_at_name` in {#list_file_names}.
    # @param count (see #list_file_names)
    # @return Hash of `keys` and `nextApplicationKeyId` (for iterating)
    # @see https://www.backblaze.com/b2/docs/b2_list_keys.html
    def list_keys(start_at: nil, count: nil)
      post_api("b2_list_keys", accountId: account_id, maxKeyCount: count, startApplicationKeyId: start_at).tap do |data|
        data[:iter] = {key: "keys", start_at: data["nextApplicationKeyId"], stop: data["nextApplicationKeyId"].nil?}
      end
    end

    ##
    # Lists the parts that have been uploaded for a large file that has not been finished yet.
    # @param file_id The ID returned by {#start_large_file}. This is the file whose parts will be listed.
    # @param start_at First part number to start at. Defaults to first part uploaded for this file.
    # @param count The maximum number of parts to return from this call. The default value is 100, and the maximum allowed is 1000.
    # @return Hash with `parts` Array and `nextPartNumber` to start at.
    # @see https://www.backblaze.com/b2/docs/b2_list_parts.html
    def list_parts(file_id, start_at: nil, count: nil)
      post_api("b2_list_parts", accountId: account_id, maxPartCount: count, startPartNumber: start_at).tap do |data|
        data[:iter] = {key: "parts", start_at: data["nextPartNumber"], stop: data["nextPartNumber"].nil?}
      end
    end

    ##
    # Lists information about large file uploads that have been started, but have not been finished or canceled.
    # @param bucket_id The bucket to look for file names in.
    # @param start_at The first upload to return. If there is an upload with this ID, it will be returned in the list. If not, the first upload after this the first one after this ID.
    # @param count The maximum number of files to return from this call. The default value is 100, and the maximum allowed is 100.
    # @param prefix (see #list_file_names)
    # @return Hash with `files` and `nextFileId`
    # @see https://www.backblaze.com/b2/docs/b2_list_unfinished_large_files.html
    def list_unfinished_large_files(bucket_id, start_at: nil, count: nil, prefix: nil)
      start_id = start_at.is_a?(Hash) ? start_at[:id] : start_at
      request_attributes = {
        bucketId: bucket_id,
        startFileId: start_id,
        maxFileCount: count,
        namePrefix: prefix
      }
      post_api("b2_list_unfinished_large_files", request_attributes).tap do |data|
        data[:iter] = {key: "files", start_at: {id: data["nextFileId"]}, stop: data["nextFileId"].nil?}
      end
    end

    ##
    # Prepares for uploading the parts of a large file.
    # @param bucket_id
    # @param name
    # @param content_type MIME type of the file being uploaded. Defaults to autodecting the type
    # @param [Hash] info Additional metadata about the file which will be returned on download. Max of 10 keys.
    #   It is recommended to set at least `{src_last_modified_millis: <millis-since-1970>, large_file_sha1: <40-byte-hex>}`.
    #   You can also set `b2-cache-control`, etc. to set the `Cache-Control` header for download.
    # @return File info hash
    # @see https://www.backblaze.com/b2/docs/b2_start_large_file.html
    # @see https://www.backblaze.com/b2/docs/files.html#fileInfo How Backblaze handles file info and b2-metadata
    # @see https://www.backblaze.com/b2/docs/content-types.html Automatic content type mappings
    def start_large_file(bucket_id, name, content_type: "b2/x-auto", info: {})
      request_attributes = {
        bucketId: bucket_id,
        fileName: name,
        contentType: content_type,
        fileInfo: info
      }
      post_api("b2_start_large_file", request_attributes)
    end

    ##
    # Update metadata about an existing bucket.
    # @param bucket_id ID of the bucket to update
    # @param info (see #create_bucket)
    # @param cors (see #create_bucket)
    # @param lifecycle (see #create_bucket)
    # @param if_revision_is When set, the update will only happen if the revision number stored in the B2 service matches
    #   the one passed in. This can be used to avoid having simultaneous updates make conflicting changes.
    # @return Updated bucket
    # @raise [ApiError] when the revision does not match
    # @see https://www.backblaze.com/b2/docs/b2_update_bucket.html
    def update_bucket(bucket_id, type: nil, info: nil, cors: nil, lifecycle: nil, if_revision_is: nil)
      request_attributes = {
        accountId: account_id,
        bucketId: bucket_id,
        bucketType: type,
        bucketInfo: info,
        corsRules: cors,
        lifecycleRules: lifecycle,
        ifRevisionIs: if_revision_is
      }
      post_api("b2_update_bucket", request_attributes)
    end

    # @!endgroup

    private

    # @return [Net::HTTP::Persistent] connection pool
    def connection
      @mutex.synchronize do
        if @pid != Process.pid
          # We forked the process. Just create another
          @connection = create_connection_pool
          @pid = Process.pid
        end
      end

      @connection
    end

    def create_connection_pool
      Net::HTTP::Persistent.new(name: "#{self.class.name}-#{object_id}")
    end

    # @param endpoint b2 api action
    # @return [URI::Generic] new URI for the given endpoint
    # @see https://www.backblaze.com/b2/docs/calling.html
    def build_api_uri(endpoint)
      URI.parse("#{api_url}/b2api/#{API_VERSION}/#{endpoint}")
    end

    ##
    # Make a post request to the api endpoint.
    def post_api(endpoint, body = {})
      body = dump_json(body) unless body.is_a?(String)
      uri = build_api_uri(endpoint)

      req = Net::HTTP::Post.new(uri)
      req.body = body

      response = connection.request(uri, req)

      if response.code == "200"
        parse_json(response)
      else
        # we got an error
        err = api_error(response)
        # Potentially do some error handling here.
        raise err
      end
    end
  end
end
