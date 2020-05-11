# frozen_string_literal: true

module Backblaze
end

require "backblaze/version"

# Because this is really a Backblaze B2 gem, everything lives in the
# Backblaze::B2 namespace. Doing this was maybe a mistake, but it's fine.
require "backblaze/b2"
