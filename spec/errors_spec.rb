require 'spec_helper'

describe Backblaze::RequestError do
  let(:response) { {'code' => 'bad_request', 'message' => 'something went wrong', 'status' => 400} }
  let(:error) { Backblaze::RequestError.new(response) }

  it 'should include code and message in error message' do
    expect(error.message).to include('bad_request')
    expect(error.message).to include('something went wrong')
    expect(error.message).to include('400')
  end

  it 'should expose the response' do
    expect(error.response).to eq(response)
  end

  it 'should expose code and status' do
    expect(error.code).to eq('bad_request')
    expect(error.status).to eq(400)
  end

  it 'should allow bracket access' do
    expect(error['code']).to eq('bad_request')
  end
end

describe '#retryable?' do
  it 'should be retryable for 408, 429, 500, 503' do
    [408, 429, 500, 503].each do |status|
      error = Backblaze::RequestError.new({'code' => 'some_error', 'message' => 'err', 'status' => status})
      expect(error.retryable?).to be true
    end
  end

  it 'should be retryable for 401 with expired_auth_token' do
    error = Backblaze::RequestError.new({'code' => 'expired_auth_token', 'message' => 'expired', 'status' => 401})
    expect(error.retryable?).to be true
  end

  it 'should not be retryable for 401 with other codes' do
    error = Backblaze::RequestError.new({'code' => 'unauthorized', 'message' => 'bad key', 'status' => 401})
    expect(error.retryable?).to be false
  end

  it 'should not be retryable for 400' do
    error = Backblaze::RequestError.new({'code' => 'bad_request', 'message' => 'err', 'status' => 400})
    expect(error.retryable?).to be false
  end
end

describe '#token_expired?' do
  it 'should be true for 401 expired_auth_token' do
    error = Backblaze::RequestError.new({'code' => 'expired_auth_token', 'message' => 'expired', 'status' => 401})
    expect(error.token_expired?).to be true
  end

  it 'should be false for other errors' do
    error = Backblaze::RequestError.new({'code' => 'bad_request', 'message' => 'err', 'status' => 400})
    expect(error.token_expired?).to be false
  end
end

describe '#retry_after' do
  it 'should return nil when no header present' do
    error = Backblaze::RequestError.new({'code' => 'err', 'message' => 'err', 'status' => 429})
    expect(error.retry_after).to be_nil
  end

  it 'should return seconds from Retry-After header' do
    response = double('response', :[] => nil)
    allow(response).to receive(:[]).with('code').and_return('service_unavailable')
    allow(response).to receive(:[]).with('message').and_return('busy')
    allow(response).to receive(:[]).with('status').and_return(503)
    allow(response).to receive(:respond_to?).with(:headers).and_return(true)
    allow(response).to receive(:headers).and_return({'retry-after' => '5'})

    error = Backblaze::RequestError.new(response)
    expect(error.retry_after).to eq(5)
  end
end

describe Backblaze::DestroyErrors do
  it 'should report number of failures' do
    errors = [Backblaze::FileError.new({'code' => 'err', 'message' => 'fail', 'status' => 500})]
    error = Backblaze::DestroyErrors.new(errors)
    expect(error.message).to include('1 file(s)')
    expect(error.errors).to eq(errors)
  end
end
