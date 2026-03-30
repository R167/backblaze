# Backblaze

The Backblaze ruby gem is an implementation of the [Backblaze B2 Cloud Storage API](https://www.backblaze.com/b2/docs/). It provides an object-oriented interface for dealing with buckets and files. Always assume that data retrieved is a snapshot from when the object was created.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'backblaze'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install backblaze

## Usage

### Authentication

```ruby
require 'backblaze'

Backblaze::B2.login(account_id: 'your_account_id', application_key: 'your_application_key')

# Or load from a JSON/YAML file:
# {"account_id": "...", "application_key": "..."}
Backblaze::B2.credentials_file('credentials.json')
```

### Buckets

```ruby
# List all buckets
buckets = Backblaze::B2::Bucket.buckets

# Find by name
bucket = Backblaze::B2::Bucket.find(name: 'my-bucket')

bucket.name       # => "my-bucket"
bucket.id         # => "4a48fe8875c6214145260818"
bucket.public?    # => true

# Create
bucket = Backblaze::B2::Bucket.create(name: 'my-new-bucket', type: :public)

# Update type
bucket.update(type: :private)

# Delete (must be empty)
bucket.destroy!
```

### Uploading

```ruby
# Upload a string
file = Backblaze::B2::File.create(
  data: 'Hello, World!',
  bucket: bucket,
  name: 'hello.txt',
  content_type: 'text/plain'
)

# Upload from disk
file = Backblaze::B2::File.create(
  data: File.open('/path/to/photo.jpg'),
  bucket: bucket
)

# With custom metadata
file = Backblaze::B2::File.create(
  data: csv_string,
  bucket: bucket,
  name: 'report.csv',
  info: { 'author' => 'backblaze-gem' }
)
```

### Listing Files

```ruby
files = bucket.files(limit: 100)
files = bucket.files(cache: true)   # cached on second call

# With versions
files = bucket.file_versions
```

### Downloading

```ruby
# Files created from a bucket know their bucket name
content = file.download

# Get download URLs
url = file.download_url
url = file.file_id_download_url

# Download a specific version
content = file.versions.first.download
```

### File Info & Versions

```ruby
versions = file.versions
info = versions.first.get_info

# Look up by ID
info = Backblaze::B2::FileVersion.get_info(file_id: 'file_id_here')
```

### Deleting

```ruby
# Delete all versions (threaded)
file.destroy!(thread_count: 4)

# Delete a specific version
file.versions.last.destroy!

# Hide a file (soft delete)
file.hide
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/R167/backblaze. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
