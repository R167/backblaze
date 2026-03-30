require 'spec_helper'

describe Backblaze::B2::FileVersion do
  before { stub_login }

  let(:version) do
    Backblaze::B2::FileVersion.new(
      file_id: 'file_id_123',
      size: 256,
      upload_timestamp: Time.now.to_i * 1000,
      action: 'upload',
      file_name: 'documents/report.pdf'
    )
  end

  describe '#initialize' do
    it 'should set attributes' do
      expect(version.file_id).to eq('file_id_123')
      expect(version.size).to eq(256)
      expect(version.action).to eq('upload')
      expect(version.file_name).to eq('documents/report.pdf')
      expect(version.upload_timestamp).to be_a(Time)
    end

    it 'should ignore unknown keyword args' do
      expect {
        Backblaze::B2::FileVersion.new(
          file_id: 'id', size: 1, upload_timestamp: 1000,
          action: 'upload', file_name: 'f.txt', content_type: 'text/plain'
        )
      }.not_to raise_error
    end
  end

  describe '#get_info' do
    it 'should fetch file info from the API' do
      stub_request(:post, /.*b2_get_file_info.*/).to_return(
        body: {
          'fileId' => 'file_id_123',
          'fileName' => 'documents/report.pdf',
          'contentLength' => 256,
          'contentType' => 'application/pdf',
          'fileInfo' => {'author' => 'test'}
        }.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      info = version.get_info
      expect(info[:file_id]).to eq('file_id_123')
      expect(info[:content_type]).to eq('application/pdf')
    end

    it 'should cache the result' do
      stub = stub_request(:post, /.*b2_get_file_info.*/).to_return(
        body: {'fileId' => 'file_id_123', 'fileName' => 'report.pdf', 'contentLength' => 256, 'contentType' => 'application/pdf', 'fileInfo' => {}}.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      version.get_info
      version.get_info
      expect(stub).to have_been_requested.once
    end

    it 'should raise on error' do
      stub_request(:post, /.*b2_get_file_info.*/).to_return(
        body: '{"status":404,"code":"not_found","message":"file not found"}',
        headers: {'Content-Type' => 'application/json'},
        status: 404
      )

      expect { version.get_info }.to raise_error(Backblaze::FileError, /not_found/)
    end
  end

  describe '#download_url' do
    it 'should build the correct download URL' do
      url = version.download_url
      expect(url).to include('b2_download_file_by_id')
      expect(url).to include('file_id_123')
      expect(url).to start_with('https://f900.backblaze.com')
    end
  end

  describe '#destroy!' do
    it 'should delete the file version' do
      stub_request(:post, /.*b2_delete_file_version.*/).to_return(
        body: '{"fileId":"file_id_123","fileName":"documents/report.pdf"}',
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      version.destroy!
      expect(version.destroyed?).to be true
      expect(version.exists?).to be false
    end

    it 'should raise on error with descriptive message' do
      stub_request(:post, /.*b2_delete_file_version.*/).to_return(
        body: '{"status":400,"code":"bad_request","message":"cannot delete"}',
        headers: {'Content-Type' => 'application/json'},
        status: 400
      )

      expect { version.destroy! }.to raise_error(Backblaze::FileError, /bad_request.*cannot delete/)
    end
  end

  describe '#download' do
    it 'should download file content by ID' do
      stub_request(:get, /.*b2_download_file_by_id.*/).to_return(
        body: 'file content here',
        status: 200
      )

      content = version.download
      expect(content).to eq('file content here')
    end
  end

  describe '.get_info' do
    it 'should get file info by ID without an instance' do
      stub_request(:post, /.*b2_get_file_info.*/).to_return(
        body: {
          'fileId' => 'some_file_id',
          'fileName' => 'test.txt',
          'contentLength' => 100,
          'contentType' => 'text/plain',
          'fileInfo' => {}
        }.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )

      info = Backblaze::B2::FileVersion.get_info(file_id: 'some_file_id')
      expect(info[:file_name]).to eq('test.txt')
      expect(info[:content_type]).to eq('text/plain')
    end
  end
end
