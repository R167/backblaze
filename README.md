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
# ENV['BACKBLAZE_B2_API_KEY']    #=> "some_api_key_(the_secret_part)"

Backblaze::B2.default_account #=> An account object
```

## Versioning

This library aims to adhere to [Semantic Versioning 2.0.0](https://semver.org/). Violations of this scheme should be reported as bugs. Specifically, if a minor or patch version is released that breaks backward compatibility, that version should be yanked and/or a new version should be released that restores compatibility. Breaking changes to the public API will only be introduced with new major versions. As a result of this policy, you can (and should) specify a dependency on this gem using the Pessimistic Version Constraint with two digits of precision.

Note: The gem is currently still in 0.y.z. Per Sem Ver 2.0.0, breaking changes may still be made on what would normally be considered "minor" versions. If you have a critical application, I would recommend waiting for a major version release, or at least locking down to the patch. Ultimately, the goal is to probably have the major version match the Backblaze B2 API version (though I'm not committing to that quite yet).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
