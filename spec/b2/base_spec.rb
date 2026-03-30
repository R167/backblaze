require 'spec_helper'

describe Backblaze::B2::Base do
  before { stub_login }

  describe '.with_retry' do
    it 'should return the block result on success' do
      result = Backblaze::B2::Base.with_retry { 42 }
      expect(result).to eq(42)
    end

    it 'should retry on retryable errors' do
      attempts = 0
      allow(Backblaze::B2::Base).to receive(:sleep)

      result = Backblaze::B2::Base.with_retry(max_retries: 3) do
        attempts += 1
        if attempts < 3
          raise Backblaze::FileError.new({'code' => 'internal_error', 'message' => 'err', 'status' => 500})
        end
        'success'
      end

      expect(result).to eq('success')
      expect(attempts).to eq(3)
    end

    it 'should raise after exhausting retries' do
      allow(Backblaze::B2::Base).to receive(:sleep)

      expect {
        Backblaze::B2::Base.with_retry(max_retries: 2) do
          raise Backblaze::FileError.new({'code' => 'internal_error', 'message' => 'err', 'status' => 500})
        end
      }.to raise_error(Backblaze::FileError)
    end

    it 'should not retry non-retryable errors' do
      attempts = 0

      expect {
        Backblaze::B2::Base.with_retry(max_retries: 3) do
          attempts += 1
          raise Backblaze::FileError.new({'code' => 'bad_request', 'message' => 'err', 'status' => 400})
        end
      }.to raise_error(Backblaze::FileError)

      expect(attempts).to eq(1)
    end

    it 'should reauthorize on expired token' do
      allow(Backblaze::B2::Base).to receive(:sleep)

      attempts = 0
      expect(Backblaze::B2).to receive(:reauthorize!).once

      result = Backblaze::B2::Base.with_retry(max_retries: 3) do
        attempts += 1
        if attempts == 1
          raise Backblaze::FileError.new({'code' => 'expired_auth_token', 'message' => 'expired', 'status' => 401})
        end
        'ok'
      end

      expect(result).to eq('ok')
    end

    it 'should use exponential backoff' do
      expect(Backblaze::B2::Base).to receive(:sleep).with(1).ordered
      expect(Backblaze::B2::Base).to receive(:sleep).with(2).ordered

      attempts = 0
      Backblaze::B2::Base.with_retry(max_retries: 3) do
        attempts += 1
        if attempts <= 2
          raise Backblaze::FileError.new({'code' => 'internal_error', 'message' => 'err', 'status' => 500})
        end
        'done'
      end
    end

    it 'should respect Retry-After header' do
      response = double('response')
      allow(response).to receive(:[]).with('code').and_return('service_unavailable')
      allow(response).to receive(:[]).with('message').and_return('busy')
      allow(response).to receive(:[]).with('status').and_return(503)
      allow(response).to receive(:respond_to?).with(:headers).and_return(true)
      allow(response).to receive(:headers).and_return({'retry-after' => '10'})

      expect(Backblaze::B2::Base).to receive(:sleep).with(10)

      attempts = 0
      Backblaze::B2::Base.with_retry(max_retries: 1) do
        attempts += 1
        raise Backblaze::FileError.new(response) if attempts == 1
        'ok'
      end
    end
  end
end
