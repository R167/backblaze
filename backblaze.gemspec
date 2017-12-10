# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'backblaze/version'

Gem::Specification.new do |spec|
  spec.name          = "backblaze"
  spec.version       = Backblaze::VERSION
  spec.authors       = ["Alex Tsui", "Winston Durand"]
  spec.email         = ["alextsui05@gmail.com"]

  spec.summary       = %q{Interface for the Backblaze B2 Cloud.}
  spec.description   = %q{Abstraction for the Backblaze B2 Cloud Storage API. Original by github.com:R167/backblaze}
  spec.homepage      = "https://github.com/alextsui05/backblaze"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "webmock"

  spec.add_dependency "httparty"

  spec.required_ruby_version = '>= 2.1.0'
end
