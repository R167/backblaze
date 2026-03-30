require 'spec_helper'

describe Backblaze::B2 do
  describe '.login' do
    context 'failed login' do
      it 'should fail when missing params' do
        expect { Backblaze::B2.login }.to raise_error(ArgumentError)
      end

      it 'should raise AuthError on failure' do
        stub_request(:get, 'https://api.backblazeb2.com/b2api/v2/b2_authorize_account').
          with(basic_auth: ['failed', 'login']).
          to_return(
            body: '{"code":"unauthorized","message":"invalid_authorization_headers","status":401}',
            headers: {'Content-Type' => 'application/json'},
            status: 401
          )
        expect {Backblaze::B2.login(account_id: 'failed', application_key: 'login')}.to raise_error(Backblaze::AuthError)
      end
    end

    context 'successful login with v2 response' do
      let(:v2_success) do
        {
          accountId: "YOUR_ACCOUNT_ID",
          authorizationToken: "auth_token_v2",
          apiInfo: {
            storageApi: {
              apiUrl: "https://api900.backblaze.com",
              downloadUrl: "https://f900.backblaze.com",
              recommendedPartSize: 100_000_000,
              absoluteMinimumPartSize: 5_000_000,
              allowed: {
                capabilities: ["listBuckets", "readFiles", "writeFiles"],
                buckets: nil,
                namePrefix: nil
              }
            }
          }
        }
      end

      before do
        stub_request(:get, 'https://api.backblazeb2.com/b2api/v2/b2_authorize_account').
          with(basic_auth: ['real', 'login']).
          to_return(
            body: v2_success.to_json,
            headers: {'Content-Type' => 'application/json'},
            status: 200,
          )
      end

      it 'should succeed' do
        expect { Backblaze::B2.login(account_id: 'real', application_key: 'login') }.to_not raise_error
      end

      it 'should extract fields from apiInfo.storageApi' do
        Backblaze::B2.login(account_id: 'real', application_key: 'login')

        expect(Backblaze::B2.api_url).to eq("https://api900.backblaze.com")
        expect(Backblaze::B2.account_id).to eq("YOUR_ACCOUNT_ID")
        expect(Backblaze::B2.token).to eq("auth_token_v2")
        expect(Backblaze::B2.download_url).to eq("https://f900.backblaze.com")
        expect(Backblaze::B2.recommended_part_size).to eq(100_000_000)
        expect(Backblaze::B2.absolute_minimum_part_size).to eq(5_000_000)
      end
    end

    context 'successful login with v1 response (fallback)' do
      let(:v1_success) do
        {
          accountId: "YOUR_ACCOUNT_ID",
          authorizationToken: "auth_token_v1",
          apiUrl: "https://api900.backblaze.com",
          downloadUrl: "https://f900.backblaze.com",
          recommendedPartSize: 100_000_000,
          absoluteMinimumPartSize: 5_000_000
        }
      end

      it 'should handle v1 top-level fields' do
        stub_request(:get, 'https://api.backblazeb2.com/b2api/v1/b2_authorize_account').
          with(basic_auth: ['v1user', 'v1key']).
          to_return(
            body: v1_success.to_json,
            headers: {'Content-Type' => 'application/json'},
            status: 200,
          )

        Backblaze::B2.login(account_id: 'v1user', application_key: 'v1key', api_path: '/b2api/v1/')

        expect(Backblaze::B2.api_url).to eq("https://api900.backblaze.com")
        expect(Backblaze::B2.download_url).to eq("https://f900.backblaze.com")
        expect(Backblaze::B2.token).to eq("auth_token_v1")
      end
    end
  end

  describe '.credentials_file' do
    it 'should load from a JSON file' do
      stub_request(:get, 'https://api.backblazeb2.com/b2api/v2/b2_authorize_account').
        with(basic_auth: ['json_account', 'json_key']).
        to_return(
          body: {accountId: 'json_account', authorizationToken: 'token', apiInfo: {storageApi: {apiUrl: 'https://api.backblaze.com', downloadUrl: 'https://f.backblaze.com'}}}.to_json,
          headers: {'Content-Type' => 'application/json'},
          status: 200
        )

      file = Tempfile.new(['creds', '.json'])
      file.write('{"account_id":"json_account","application_key":"json_key"}')
      file.close

      result = Backblaze::B2.credentials_file(file.path)
      expect(result).to be true

      file.unlink
    end

    it 'should return false when missing params' do
      file = Tempfile.new(['creds', '.json'])
      file.write('{"account_id":"only_id"}')
      file.close

      result = Backblaze::B2.credentials_file(file.path, raise_errors: false)
      expect(result).to be false

      file.unlink
    end
  end
end
