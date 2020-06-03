lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "backblaze/version"

Gem::Specification.new do |spec|
  spec.name = "backblaze"
  spec.version = Backblaze::VERSION
  spec.authors = ["Winston Durand"]
  spec.email = ["me@winstondurand.com"]

  spec.summary = "Interface for the Backblaze B2 Cloud"
  spec.description = "Intended to offer a way to interact with Backblaze B2 Cloud Storage without touching the API directly."
  spec.homepage = "https://github.com/R167/backblaze"
  spec.license = "MIT"

  # Ignore the internal bin tools and specs.
  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(bin|test|spec|features)/}) }
  # spec.bindir = "exe"
  # spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.5.0"

  spec.add_runtime_dependency "multi_json", "~> 1.0"
  spec.add_runtime_dependency "net-http-persistent", ">= 3.0.0", "< 6"
end
