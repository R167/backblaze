# Backblaze

The Backblaze ruby gem is an implementation of the [Backblaze B2 Cloud Storage API](https://www.backblaze.com/b2/docs/). In addition to simplifying calls, it also implements an object oriented structure for dealing with files. Calling the api through different objects will not cause each to get updated. Always assume that data retrieved is just a snapshot from when the object was retrieved.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'backblaze'
```

And then execute:

```bash
bundle
```

Or install it yourself as:

```bash
gem install backblaze
```

## Getting Started

Usage requires having a Backblaze account. You can sign up for one on [backblaze.com](https://www.backblaze.com/b2/cloud-storage.html), or follow their quick [Getting Started](https://www.backblaze.com/b2/docs/quick_account.html) guide. Once you have your account and account key, you're ready to go.

## Usage

For simple usage, `Backblaze::B2` provides a default account object and will try to configure itself through the environment variables `BACKBLAZE_B2_API_KEY_ID` and `BACKBLAZE_B2_API_KEY`. Refer to their [Application Keys](https://www.backblaze.com/b2/docs/application_keys.html) documentation for more info one what these keys mean.

```ruby
# ENV['BACKBLAZE_B2_API_KEY_ID'] #=> "some_api_key_id"
# ENV['BACKBLAZE_B2_API_KEY_ID'] #=> "some_api_key_(the_secret_part)"

Backblaze::B2.default_account #=> An account object
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/R167/backblaze]. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
