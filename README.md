# Backblaze

[![RSpec tests](https://github.com/R167/backblaze/workflows/CI/badge.svg)](https://github.com/R167/backblaze/actions?query=workflow%3ACI+branch%3Amaster)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/backblaze.svg)](https://badge.fury.io/rb/backblaze)

The Backblaze ruby gem is an implementation of the [Backblaze B2 Cloud Storage API](https://www.backblaze.com/b2/docs/). In addition to simplifying calls, it also implements an object oriented structure for dealing with files. Calling the api through different objects will not cause each to get updated. Always assume that data retrieved is just a snapshot from when the object was retrieved.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "backblaze"
# or with pessimistic versioning
gem "backblaze", "~> 0.4.0"
```

And then run:

```bash
bundle
```

Or install it yourself as:

```bash
gem install backblaze
```

## Getting Started

Usage requires having a Backblaze account. You can sign up for one on [backblaze.com](https://www.backblaze.com/b2/cloud-storage.html), or follow their quick [Getting Started](https://www.backblaze.com/b2/docs/quick_account.html) guide. Once you have your account and account key, you're ready to go.

Full documentation on this gem is available

## Documentation

Documentation follows the YARD syntax, and is available on [Ruby Doc](https://www.rubydoc.info/gems/backblaze/frames).

### Usage

For simple usage, `Backblaze::B2` provides a default account object and will try to configure itself through the environment variables `BACKBLAZE_B2_API_KEY_ID` and `BACKBLAZE_B2_API_KEY`. Refer to their [Application Keys](https://www.backblaze.com/b2/docs/application_keys.html) documentation for more info one what these keys mean.

```ruby
# ENV['BACKBLAZE_B2_API_KEY_ID'] #=> "some_api_key_id"
# ENV['BACKBLAZE_B2_API_KEY']    #=> "some_api_key_(the_secret_part)"
Backblaze::B2.login!
Backblaze::B2.default_account #=> the default Account
```

It's also possible to set these values directly in a config block, particularly useful if you're getting your secrets some other way. If you're using Rails, this should go in your initializer.

```ruby
Backblaze::B2.config do |c|
  c.application_key_id = "<application-key-id>"
  c.application_key = "<application-key-secret>"
end

# Because we used .config, .login! is implied
Backblaze::B2.default_account #=> the default Account
```

Note: `login!` and `config` don't **actually** trigger a login, but instead "unlock" the default account.

If for some reason you just want a minimal interface for interacting with B2, you can just use `Backblaze::B2::Api` directly through `require "backblaze/b2/api"`.

## Versioning

This library aims to adhere to [Semantic Versioning 2.0.0](https://semver.org/). Violations of this scheme should be reported as bugs. Specifically, if a minor or patch version is released that breaks backward compatibility, that version should be yanked and/or a new version should be released that restores compatibility. Breaking changes to the public API will only be introduced with new major versions. As a result of this policy, you can (and should) specify a dependency on this gem using the Pessimistic Version Constraint with two digits of precision.

Note: The gem is currently still in 0.y.z. Per Sem Ver 2.0.0, breaking changes may still be made on what would normally be considered "minor" versions. If you have a critical application, I would recommend waiting for a major version release, or at least locking down to the patch. Ultimately, the goal is to probably have the major version match the Backblaze B2 API version (though I'm not committing to that quite yet).

## Contributing

Contributions to this gem are welcome! If you find something broken, definitely submit an issue and feel free to contribute a PR with a fix :D

- Fork the repo
- Make your changes
- Ensure all specs pass (`bundle exec rake spec`)
- Send a pull request
- If you want to be more involved, please reach out about becoming a maintainer

### Development help

Once you've cloned the repo, all dependencies can be installed using `bundle install`. For ease of use, there's a couple rake tasks to know about:

```bash
# Run the specs
bundle exec rake spec
# Spin up irb with the local gem already included. Use the helper method `auth!` to get an account
# This will also load and .env files
bundle exec rake console
# Run StandardRB to find issues
bundle exec rake standard
bundle exec rake standard:fix   # auto apply fixes
```

Finally:

- Keep your code reasonable. Refer to the [coding guide](CODING_GUIDE.md) for some gentle guidance.
- Specs!
  - If you're adding a feature, write specs.
  - If you're fixing a bug, make sure there's a spec so it doesn't happen again in the future.
- Be clear about what your PR is doing. Don't cram 12 new, disparate features into one PR.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
