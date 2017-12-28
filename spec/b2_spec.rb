require 'spec_helper'

describe Backblaze::B2 do
  describe '.login' do
    context 'failed login' do
      it 'should fail when missing params' do
        expect { Backblaze::B2.login }.to raise_error(ArgumentError)
      end

      it 'should raise AuthError on failure' do
        stub_request(:get, 'https://api.backblazeb2.com/b2api/v1/b2_authorize_account')
          .to_return(
            body: '{"code":"unauthorized","message":"invalid_authorization_headers","status":401}',
            headers: { 'Content-Type' => 'application/json' },
            status: 401
          )
        expect { Backblaze::B2.login(account_id: 'failed', application_key: 'login') }.to raise_error(Backblaze::AuthError)
      end
    end

    context 'successful login' do
      let(:success) do
        {
          accountId: 'YOUR_ACCOUNT_ID',
          apiUrl: 'https://api900.backblaze.com',
          authorizationToken: '2_20150807002553_443e98bf57f978fa58c284f8_24d25d99772e3ba927778b39c9b0198f412d2163_acct',
          downloadUrl: 'https://f900.backblaze.com'
        }
      end

      before do
        stub_request(:get, 'https://api.backblazeb2.com/b2api/v1/b2_authorize_account')
          .to_return(
            status: 200,
            body: success.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'should succeed' do
        expect { Backblaze::B2.login(account_id: 'real', application_key: 'login') }.to_not raise_error
      end

      it 'should set variables' do
        Backblaze::B2.login(account_id: 'real', application_key: 'login')
        expect(Backblaze::B2.api_url).to eq(success[:apiUrl])
        expect(Backblaze::B2.account_id).to eq(success[:accountId])
        expect(Backblaze::B2.token).to eq(success[:authorizationToken])
        expect(Backblaze::B2.download_url).to eq(success[:downloadUrl])
      end
    end
  end
end
