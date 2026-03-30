# Backblaze

The Backblaze ruby gem is an implementation of the [Backblaze B2 Cloud Storage API](https://www.backblaze.com/b2/docs/). In addition to simplifying calls, it also implements an object oriented structure for dealing with files. Calling the api through different objects will not cause each to get updated. Always assume that data retrieved is just a snapshot from when the object was retrieved.

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

Authenticate with your Backblaze B2 account ID and application key:

```ruby
require 'backblaze'

Backblaze::B2.login(account_id: 'your_account_id', application_key: 'your_application_key')
```

Or load credentials from a JSON or YAML file:

```ruby
# credentials.json: {"account_id": "...", "application_key": "..."}
Backblaze::B2.credentials_file('credentials.json')
```

### Buckets

```ruby
# List all buckets
buckets = Backblaze::B2::Bucket.buckets

# Find a bucket by name
bucket = Backblaze::B2::Bucket.find(name: 'my-bucket')

# Create a new bucket
bucket = Backblaze::B2::Bucket.create(name: 'my-new-bucket', type: :public)

# Update bucket type
bucket.update(type: :private)

# Check bucket type
bucket.public?   # => false
bucket.private?  # => true

# Delete an empty bucket
bucket.destroy!
```

### Uploading Files

```ruby
# Upload a string
file = Backblaze::B2::File.create(
  data: 'Hello, World!',
  bucket: bucket,
  name: 'hello.txt',
  content_type: 'text/plain'
)

# Upload a file from disk
file = Backblaze::B2::File.create(
  data: File.open('/path/to/photo.jpg'),
  bucket: bucket
)

# Upload with a base path and custom metadata
file = Backblaze::B2::File.create(
  data: 'data',
  bucket: bucket,
  name: 'report.csv',
  base_name: 'reports/2024',
  info: { 'author' => 'backblaze-gem' }
)
```

### Listing Files

```ruby
# List files by name
files = bucket.file_names(limit: 100)

# List all file versions
files = bucket.file_versions(limit: -1)

# Use caching to avoid repeated API calls
files = bucket.file_names(cache: true)
files = bucket.file_names(cache: true)  # uses cached result
```

### Downloading Files

```ruby
# Download by file name
content = file.download(bucket: bucket)

# Get download URLs
url = file.download_url(bucket: bucket)
url = file.file_id_download_url

# Download a specific version
content = file.versions.first.download
```

### File Versions

```ruby
# Get all versions of a file
versions = file.versions

# Get info about a specific version
info = versions.first.get_info

# Look up file info by ID
info = Backblaze::B2::FileVersion.get_info(file_id: 'file_id_here')
```

### Deleting Files

```ruby
# Delete all versions of a file (threaded)
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
