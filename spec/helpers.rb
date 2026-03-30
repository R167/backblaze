module Helpers
  def file_list(size: 10, next_item: nil, start_field: 'nextFileName')
    files = []
    size.times do
      files << {
        'action' => 'upload',
        'fileId' => SecureRandom.uuid.tr('-', '_'),
        'fileName' => "random_file_#{rand(0..10000)}.txt",
        'contentLength' => rand(10..1000),
        'uploadTimestamp' => Time.now.to_i * 1000
      }
    end

    {
      'files' => files,
      start_field => next_item
    }
  end

  def file_version_list(size: 10, next_id: nil, next_name: nil)
    files = []
    size.times do
      files << {
        'action' => 'upload',
        'fileId' => SecureRandom.uuid.tr('-', '_'),
        'fileName' => "random_file_#{rand(0..10000)}.txt",
        'contentLength' => rand(10..1000),
        'uploadTimestamp' => Time.now.to_i * 1000
      }
    end

    {
      'files' => files,
      'nextFileId' => next_id,
      'nextFileName' => next_name
    }
  end

  def stub_login
    success = {
      'accountId' => 'test_account_id',
      'authorizationToken' => 'test_auth_token',
      'apiInfo' => {
        'storageApi' => {
          'apiUrl' => 'https://api900.backblaze.com',
          'downloadUrl' => 'https://f900.backblaze.com',
          'recommendedPartSize' => 100_000_000,
          'absoluteMinimumPartSize' => 5_000_000
        }
      }
    }
    stub_request(:get, 'https://api.backblazeb2.com/b2api/v2/b2_authorize_account').
      with(basic_auth: ['test', 'test']).
      to_return(
        body: success.to_json,
        headers: {'Content-Type' => 'application/json'},
        status: 200
      )
    Backblaze::B2.login(account_id: 'test', application_key: 'test')
  end
end
