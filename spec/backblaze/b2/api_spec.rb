# frozen_string_literal: true

require "spec_helper"

describe Backblaze::B2::Api do
  let(:key_id) { "key_id" }
  let(:key_secret) { "key_secret" }
  let(:api) { Backblaze::B2::Api.new(key_id, key_secret, login: false) }

  describe "#login!" do
    before do
      stub_request(:get, "https://api.backblazeb2.com/b2api/v2/b2_authorize_account")
        .with(
          headers: {
            "Authorization" => "Basic a2V5X2lkOmtleV9zZWNyZXQ=",
            "User-Agent" => Backblaze::USER_AGENT
          }
        ).to_return(status: 200, body: "{}", headers: {})
    end

    it "tries to log in" do
      api.login!
    end
  end

  describe "#connection" do
    # Yes, this is a private method, but it's also really important that it handles forking correctly
    def connection
      api.__send__(:connection)
    end

    it "maintains the same connection" do
      # Purposefully use equal? for object identity
      expect(connection).to equal(connection)
    end

    it "creates a new connection on fork" do
      conn = connection
      id = eval_in_fork do
        connection.object_id
      end

      expect(conn.object_id).not_to eq id
      expect(conn).to equal(connection)
    end
  end
end
