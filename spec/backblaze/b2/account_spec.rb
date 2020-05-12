require 'spec_helper'

describe Backblaze::B2::Account do
  let(:application_key_id) { "fake_key_id" }
  let(:application_key) { "fake_key_secret_value" }
  let(:account) { Backblaze::B2::Account.new(application_key_id: application_key_id, application_key: application_key) }

  before do
    stub_request(:get, "https://api.backblazeb2.com/b2api/v2/b2_authorize_account").
      to_return(status: 200, body: "{}", headers: {})
  end

  describe '#with_persistent_connection' do
    it 'should call api' do
      api = double("api")
      expect(api).to receive(:with_persistent_connection)
      expect(account).to receive(:api).and_return(api)

      account.with_persistent_connection {}
    end
  end
end
