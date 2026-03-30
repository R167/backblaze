require 'spec_helper'

describe Backblaze::B2::Bucket do
  before { stub_login }

  let(:bucket) do
    Backblaze::B2::Bucket.new(
      bucket_type: 'allPublic',
      bucket_name: 'generic_bucket',
      bucket_id: 'fhdjsfhdkja',
      account_id: 'test_account_id'
    )
  end

  describe '#initialize' do
    it 'should set attributes' do
      expect(bucket.bucket_name).to eq('generic_bucket')
      expect(bucket.bucket_id).to eq('fhdjsfhdkja')
      expect(bucket.bucket_type).to eq('allPublic')
      expect(bucket.account_id).to eq('test_account_id')
    end
  end

  describe '#name / #id aliases' do
    it 'should alias name to bucket_name' do
      expect(bucket.name).to eq('generic_bucket')
    end

    it 'should alias id to bucket_id' do
      expect(bucket.id).to eq('fhdjsfhdkja')
    end
  end

  describe '#public? / #private?' do
    it 'should be public when allPublic' do
      expect(bucket.public?).to be true
      expect(bucket.private?).to be false
    end

    it 'should be private when allPrivate' do
      private_bucket = Backblaze::B2::Bucket.new(
        bucket_type: 'allPrivate', bucket_name: 'priv', bucket_id: 'id', account_id: 'acct'
      )
      expect(private_bucket.public?).to be false
      expect(private_bucket.private?).to be true
    end
  end

  describe '#==' do
    it 'should compare by bucket_name' do
      other = Backblaze::B2::Bucket.new(
        bucket_type: 'allPrivate', bucket_name: 'generic_bucket', bucket_id: 'other_id', account_id: 'acct'
      )
      expect(bucket == other).to be true
    end
  end

  describe '.create' do
    context 'success' do
      let(:success) do
        {
          "bucketId" => "4a48fe8875c6214145260818",
          "accountId" => "010203040506",
          "bucketName" => "some_bucket",
          "bucketType" => "allPublic"
        }
      end

      it 'should create a bucket' do
        stub_request(:post, /.*\/b2_create_bucket.*/).to_return(
          headers: {'Content-Type' => 'application/json'},
          body: success.to_json,
          status: 201
        )

        bucket = Backblaze::B2::Bucket.create(name: 'some_bucket', type: :public)

        expect(bucket.name).to eq('some_bucket')
        expect(bucket.id).to eq('4a48fe8875c6214145260818')
        expect(bucket.public?).to be true
      end
    end

    context 'failure' do
      it 'should raise BucketError with message' do
        stub_request(:post, /.*\/b2_create_bucket.*/).to_return(
          headers: {'Content-Type' => 'application/json'},
          body: '{"status":400,"code":"duplicate_bucket_name","message":"Bucket name is already in use"}',
          status: 400
        )

        expect {
          Backblaze::B2::Bucket.create(name: 'existing_bucket', type: :public)
        }.to raise_error(Backblaze::BucketError, /duplicate_bucket_name/)
      end
    end
  end

  describe '.buckets' do
    it 'should list all buckets' do
      stub_request(:post, /.*b2_list_buckets.*/).to_return(
        body: {
          'buckets' => [
            {'bucketId' => 'id1', 'bucketName' => 'bucket1', 'bucketType' => 'allPublic', 'accountId' => 'acct'},
            {'bucketId' => 'id2', 'bucketName' => 'bucket2', 'bucketType' => 'allPrivate', 'accountId' => 'acct'}
          ]
        }.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      buckets = Backblaze::B2::Bucket.buckets
      expect(buckets.size).to eq(2)
      expect(buckets.first.name).to eq('bucket1')
      expect(buckets.last.private?).to be true
    end
  end

  describe '.find' do
    before do
      stub_request(:post, /.*b2_list_buckets.*/).to_return(
        body: {
          'buckets' => [
            {'bucketId' => 'id1', 'bucketName' => 'target', 'bucketType' => 'allPublic', 'accountId' => 'acct'},
            {'bucketId' => 'id2', 'bucketName' => 'other', 'bucketType' => 'allPrivate', 'accountId' => 'acct'}
          ]
        }.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )
    end

    it 'should find a bucket by name' do
      found = Backblaze::B2::Bucket.find(name: 'target')
      expect(found).to_not be_nil
      expect(found.name).to eq('target')
    end

    it 'should return nil when not found' do
      expect(Backblaze::B2::Bucket.find(name: 'missing')).to be_nil
    end
  end

  describe '#destroy!' do
    it 'should delete the bucket' do
      stub_request(:post, /.*b2_delete_bucket.*/).to_return(
        body: {'bucketId' => 'fhdjsfhdkja'}.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      bucket.destroy!
      expect(bucket.destroyed?).to be true
      expect(bucket.exists?).to be false
    end

    it 'should raise on error' do
      stub_request(:post, /.*b2_delete_bucket.*/).to_return(
        body: '{"status":400,"code":"cannot_delete_non_empty_bucket","message":"bucket not empty"}',
        headers: {'Content-Type' => 'application/json'},
        status: 400
      )

      expect { bucket.destroy! }.to raise_error(Backblaze::BucketError)
    end
  end

  describe '#update' do
    it 'should update the bucket type' do
      stub_request(:post, /.*b2_update_bucket.*/).to_return(
        body: {
          'bucketId' => 'fhdjsfhdkja',
          'bucketName' => 'generic_bucket',
          'bucketType' => 'allPrivate',
          'accountId' => 'test_account_id'
        }.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      bucket.update(type: :private)
      expect(bucket.private?).to be true
    end
  end

  describe '#download_authorization' do
    it 'should generate a download auth token' do
      stub_request(:post, /.*b2_get_download_authorization.*/).to_return(
        body: {'authorizationToken' => 'download_token_123'}.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      token = bucket.download_authorization(file_name_prefix: 'photos/')
      expect(token).to eq('download_token_123')
    end
  end

  describe '#upload_url' do
    it 'should get an upload url' do
      stub_request(:post, /.*b2_get_upload_url.*/).to_return(
        body: {'uploadUrl' => 'https://upload.example.com', 'authorizationToken' => 'token'}.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      result = bucket.upload_url
      expect(result[:url]).to eq('https://upload.example.com')
      expect(result[:token]).to eq('token')
    end
  end

  describe '#files' do
    context 'success' do
      before do
        next_item = nil
        list = []
        4.times do
          files = file_list(size: 10, next_item: next_item)
          next_item = files['files'][9]['fileName']
          list.insert(0, {body: files.to_json, status: 200})
        end
        stub_request(:post, /.*\/b2_list_file_names.*/).to_return(*list)
      end

      it 'should list all files with large limit' do
        files = bucket.files(limit: 1000)
        expect(files.size).to eq 40
        expect(files.first).to be_a(Backblaze::B2::File)
      end

      it 'should limit results' do
        files = bucket.files(limit: 10)
        expect(files.size).to eq 10
      end

      it 'should use caching' do
        expect(bucket).to receive(:post).once.and_call_original

        files1 = bucket.files(limit: 10, cache: true)
        files2 = bucket.files(limit: 10, cache: true)

        expect(files1.size).to eq 10
        expect(files2).to eq files1
      end

      it 'should store bucket_name on returned files' do
        files = bucket.files(limit: 1)
        expect(files.first.bucket_name).to eq('generic_bucket')
      end
    end
  end

  describe '#file_names (deprecated compat)' do
    before do
      stub_request(:post, /.*\/b2_list_file_names.*/).to_return(
        body: file_list(size: 5).to_json,
        status: 200
      )
    end

    it 'should still work for backwards compatibility' do
      files = bucket.file_names(limit: 5)
      expect(files.size).to eq 5
      expect(files.first).to be_a(Backblaze::B2::File)
    end
  end

  describe '#file_versions' do
    it 'should list file versions grouped by name' do
      version_data = {
        'files' => [
          {'fileId' => 'v1', 'fileName' => 'a.txt', 'contentLength' => 100, 'action' => 'upload', 'uploadTimestamp' => Time.now.to_i * 1000},
          {'fileId' => 'v2', 'fileName' => 'a.txt', 'contentLength' => 90, 'action' => 'upload', 'uploadTimestamp' => (Time.now.to_i - 60) * 1000},
          {'fileId' => 'v3', 'fileName' => 'b.txt', 'contentLength' => 200, 'action' => 'upload', 'uploadTimestamp' => Time.now.to_i * 1000}
        ],
        'nextFileId' => nil
      }
      stub_request(:post, /.*b2_list_file_versions.*/).to_return(
        body: version_data.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      files = bucket.file_versions
      expect(files.size).to eq(2)
      expect(files.first).to be_a(Backblaze::B2::File)
      expect(files.first.bucket_name).to eq('generic_bucket')
    end
  end
end
