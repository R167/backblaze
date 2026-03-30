require 'spec_helper'

describe Backblaze::B2::File do
  before { stub_login }

  let(:bucket) do
    Backblaze::B2::Bucket.new(
      bucket_type: 'allPublic',
      bucket_name: 'test_bucket',
      bucket_id: 'bucket123',
      account_id: 'test_account_id'
    )
  end

  describe '.create' do
    let(:upload_url_response) do
      {
        'uploadUrl' => 'https://pod-000-1005-03.backblaze.com/b2api/v1/b2_upload_file/bucket123/token',
        'authorizationToken' => 'upload_token_123'
      }
    end

    let(:upload_response) do
      {
        'fileName' => 'test.txt',
        'bucketId' => 'bucket123',
        'contentLength' => 11,
        'fileId' => 'file_id_123',
        'action' => 'upload'
      }
    end

    before do
      stub_request(:post, /.*b2_get_upload_url.*/).to_return(
        body: upload_url_response.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )
    end

    it 'should upload string data' do
      stub_request(:post, upload_url_response['uploadUrl']).to_return(
        body: upload_response.to_json,
        status: 200
      )

      file = Backblaze::B2::File.create(
        data: 'hello world',
        bucket: bucket,
        name: 'test.txt'
      )

      expect(file).to be_a(Backblaze::B2::File)
      expect(file.file_name).to eq('test.txt')
    end

    it 'should raise error when data is nil' do
      expect {
        Backblaze::B2::File.create(data: nil, bucket: bucket, name: 'test.txt')
      }.to raise_error(ArgumentError, 'data must not be nil')
    end

    it 'should raise error when name missing for string data' do
      expect {
        Backblaze::B2::File.create(data: 'hello', bucket: 'bucket123')
      }.to raise_error(ArgumentError, 'Must provide a file name for data')
    end

    it 'should accept bucket_id string' do
      stub_request(:post, upload_url_response['uploadUrl']).to_return(
        body: upload_response.to_json,
        status: 200
      )

      file = Backblaze::B2::File.create(
        data: 'hello world',
        bucket: 'bucket123',
        name: 'test.txt'
      )

      expect(file.file_name).to eq('test.txt')
    end

    it 'should raise on upload failure' do
      stub_request(:post, upload_url_response['uploadUrl']).to_return(
        body: '{"status":500,"code":"internal_error","message":"server error"}',
        status: 500
      )

      expect {
        Backblaze::B2::File.create(data: 'hello', bucket: bucket, name: 'test.txt')
      }.to raise_error(Backblaze::FileError)
    end
  end

  describe '#download_url' do
    let(:file) do
      Backblaze::B2::File.new(
        file_name: 'photos/cat.jpg',
        bucket_id: 'bucket123',
        file_id: 'file_id_1',
        size: 100,
        upload_timestamp: Time.now.to_i * 1000,
        action: 'upload'
      )
    end

    it 'should build url with bucket object' do
      url = file.download_url(bucket: bucket)
      expect(url).to eq('https://f900.backblaze.com/file/test_bucket/photos/cat.jpg')
    end

    it 'should build url with bucket name string' do
      url = file.download_url(bucket: 'my_bucket')
      expect(url).to eq('https://f900.backblaze.com/file/my_bucket/photos/cat.jpg')
    end
  end

  describe '#versions' do
    let(:file) do
      Backblaze::B2::File.new(
        file_name: 'test.txt',
        bucket_id: 'bucket123',
        file_id: 'file_id_1',
        size: 100,
        upload_timestamp: Time.now.to_i * 1000,
        action: 'upload'
      )
    end

    it 'should fetch all versions lazily' do
      version_data = {
        'files' => [
          {'fileId' => 'v1', 'fileName' => 'test.txt', 'size' => 100, 'action' => 'upload', 'uploadTimestamp' => Time.now.to_i * 1000},
          {'fileId' => 'v2', 'fileName' => 'test.txt', 'size' => 90, 'action' => 'upload', 'uploadTimestamp' => (Time.now.to_i - 60) * 1000}
        ],
        'nextFileId' => nil
      }
      stub_request(:post, /.*b2_list_file_versions.*/).to_return(
        body: version_data.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      versions = file.versions
      expect(versions.size).to eq(2)
      expect(versions.first).to be_a(Backblaze::B2::FileVersion)
    end
  end

  describe '#destroy!' do
    let(:file) do
      Backblaze::B2::File.new(
        file_name: 'test.txt',
        bucket_id: 'bucket123',
        file_id: 'file_id_1',
        size: 100,
        upload_timestamp: Time.now.to_i * 1000,
        action: 'upload'
      )
    end

    it 'should delete all versions' do
      # Stub version listing
      version_data = {
        'files' => [
          {'fileId' => 'v1', 'fileName' => 'test.txt', 'size' => 100, 'action' => 'upload', 'uploadTimestamp' => Time.now.to_i * 1000}
        ],
        'nextFileId' => nil
      }
      stub_request(:post, /.*b2_list_file_versions.*/).to_return(
        body: version_data.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )
      stub_request(:post, /.*b2_delete_file_version.*/).to_return(
        body: '{"fileId":"v1","fileName":"test.txt"}',
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      file.destroy!
      expect(file.exists?).to be false
    end
  end

  describe '#hide' do
    let(:file) do
      Backblaze::B2::File.new(
        file_name: 'test.txt',
        bucket_id: 'bucket123',
        file_id: 'file_id_1',
        size: 100,
        upload_timestamp: Time.now.to_i * 1000,
        action: 'upload'
      )
    end

    it 'should hide the file and return a hide marker' do
      stub_request(:post, /.*b2_hide_file.*/).to_return(
        body: {
          'fileId' => 'hide_marker_1',
          'fileName' => 'test.txt',
          'action' => 'hide',
          'size' => 0,
          'uploadTimestamp' => Time.now.to_i * 1000
        }.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      version = file.hide
      expect(version).to be_a(Backblaze::B2::FileVersion)
      expect(version.action).to eq('hide')
    end
  end

  describe '#download' do
    let(:file) do
      Backblaze::B2::File.new(
        file_name: 'test.txt',
        bucket_id: 'bucket123',
        file_id: 'file_id_1',
        size: 11,
        upload_timestamp: Time.now.to_i * 1000,
        action: 'upload'
      )
    end

    it 'should download the file content' do
      stub_request(:get, 'https://f900.backblaze.com/file/test_bucket/test.txt').to_return(
        body: 'hello world',
        status: 200
      )

      content = file.download(bucket: bucket)
      expect(content).to eq('hello world')
    end
  end

  describe '#method_missing' do
    let(:file) do
      Backblaze::B2::File.new(
        file_name: 'test.txt',
        bucket_id: 'bucket123',
        file_id: 'file_id_1',
        size: 42,
        upload_timestamp: Time.now.to_i * 1000,
        action: 'upload'
      )
    end

    it 'should delegate to latest version' do
      expect(file.file_id).to eq('file_id_1')
      expect(file.size).to eq(42)
    end

    it 'should raise NoMethodError for unknown methods' do
      expect { file.nonexistent_method }.to raise_error(NoMethodError)
    end
  end
end
