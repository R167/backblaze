require 'spec_helper'

describe Backblaze::B2::UrlManager do
  let(:manager){ Backblaze::B2::UrlManager.instance }
  let(:upload_url){ {url: 'example.com'} }
  describe '#lease_url' do
    it "should add a URL when none are present" do
      stub_request(:post, /.*\/b2_get_upload_url.*/).to_return(
        headers: {'Content-Type' => 'application/json'},
        body: success.to_json,
        status: 201
      )
    end
  end
end
