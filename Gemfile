source "https://rubygems.org"

# Specify your gem's dependencies in backblaze.gemspec
group :runtime do
  # mark runtime gems
  gemspec
end

gem "rake"

group :development, :test do
  gem "standard", "~> 1.0.0"
  gem "dotenv", require: false
end

group :test do
  gem "rspec", "~> 3.9.0"
  gem "webmock", "~> 3.8.0"
  gem "simplecov", "~> 0.17.0"
end

group :doc do
  gem "yard"
end
