require 'spec_helper'

describe Backblaze::Utils do
  include Backblaze::Utils

  describe '#b2_encode_file_name' do
    it 'should preserve forward slashes' do
      expect(b2_encode_file_name('photos/cats/kitten.jpg')).to eq('photos/cats/kitten.jpg')
    end

    it 'should encode spaces as %20' do
      expect(b2_encode_file_name('my file.txt')).to eq('my%20file.txt')
    end

    it 'should encode + as %2B' do
      expect(b2_encode_file_name('a+b.txt')).to eq('a%2Bb.txt')
    end

    it 'should encode special characters' do
      expect(b2_encode_file_name('café.txt')).to include('%')
    end

    it 'should handle nested paths with spaces' do
      result = b2_encode_file_name('my folder/my file.txt')
      expect(result).to eq('my%20folder/my%20file.txt')
    end
  end

  describe '#response_to_hash' do
    it 'should convert camelCase keys to snake_case symbols' do
      result = response_to_hash({'fileName' => 'test.txt', 'contentLength' => 42})
      expect(result).to eq({file_name: 'test.txt', content_length: 42})
    end
  end
end
