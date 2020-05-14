$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "backblaze"
require "webmock/rspec"
require File.expand_path("../helpers", __FILE__)

RSpec.configure do |c|
  c.include Helpers
  c.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
