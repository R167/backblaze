module Backblaze::B2
  class File < Base
    def initialize(file_id:, file_name:, size:, account_id:)
      @versions = []

    end
  end
end
