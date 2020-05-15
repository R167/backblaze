# frozen_string_literal: true

module Backblaze
  VERSION = "0.4.0"

  # User agent for all requests in this gem. This follows backblaze's user agent recommendations
  # listed on their [integration checklist](https://www.backblaze.com/b2/docs/integration_checklist.html)
  USER_AGENT = "backblaze-rb/#{VERSION}+#{RUBY_ENGINE}/#{RUBY_VERSION}"
end
