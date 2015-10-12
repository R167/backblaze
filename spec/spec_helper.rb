$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'backblaze'
require 'webmock/rspec'
require File.expand_path('../helpers', __FILE__)

RSpec.configure do |c|
  c.include Helpers
end
