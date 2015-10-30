require 'spec_helper'

describe Backblaze::B2::Bucket do
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

        success.each do |key, value|
          expect(bucket.send(Backblaze::Utils.underscore(key))).to eq value
        end
      end
    end
  end

  describe '.files' do
    let(:bucket){Backblaze::B2::Bucket.new(bucket_type: 'allPublic', bucket_name: 'generic_bucket', bucket_id: 'fhdjsfhdkja', account_id: 'fhdjkafd')}

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

      it 'should process all on large limit' do
        files = bucket.file_names(limit: 1000, convert: false, double_check_server: true)
        expect(files.size).to eq 40
      end

      it 'should process some on a small limit' do
        files = bucket.file_names(limit: 20, convert: false, double_check_server: true)
        expect(files.size).to eq 20
      end

      it 'should process use caching' do
        expect(bucket).to receive(:post).once.and_call_original

        files1 = bucket.file_names(limit: 10, convert: false, cache: true)
        files2 = bucket.file_names(limit: 10, convert: false, cache: true)

        expect(files1.size).to eq 10
        expect(files2).to eq files1
      end

    end
  end
end
