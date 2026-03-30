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

describe Backblaze::DestroyErrors do
  it 'should report number of failures' do
    errors = [Backblaze::FileError.new({'code' => 'err', 'message' => 'fail', 'status' => 500})]
    error = Backblaze::DestroyErrors.new(errors)
    expect(error.message).to include('1 file(s)')
    expect(error.errors).to eq(errors)
  end
end
