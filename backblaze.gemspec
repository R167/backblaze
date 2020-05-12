# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'backblaze/version'

Gem::Specification.new do |spec|
  spec.name          = "backblaze"
  spec.version       = Backblaze::VERSION
  spec.authors       = ["Winston Durand"]
  spec.email         = ["me@winstondurand.com"]

  spec.summary       = %q{Interface for the Backblaze B2 Cloud}
  spec.description   = %q{Intended to offer a way to interact with Backblaze B2 Cloud Storage without touching the API directly.}
  spec.homepage      = "https://github.com/R167/backblaze"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(bin|test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.4.0'

  spec.add_dependency "http", '~> 4.0'
  spec.add_dependency "multi_json", '~> 1.0'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "yard"
end
