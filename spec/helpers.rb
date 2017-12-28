module Helpers
  require 'securerandom'
  def file_list(size: 10, next_item: nil)
    files = []
    size.times do
      files << {
        'action' => 'upload',
        'fileId' => SecureRandom.uuid.tr('-', '_'),
        'fileName' => "random_file_#{rand(0..10_000)}.txt",
        'size' => rand(10..1000),
        'uploadTimestamp' => Time.now.to_i
      }
    end

    {
      'files' => files,
      'nextFileName' => next_item
    }
  end
end
