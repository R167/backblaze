# backblaze

The `paperclip` gem abstracts the [Backblaze B2 Cloud Storage API](https://www.backblaze.com/b2/docs/).
It was started by Winston Durand at [R167/backblaze](https://github.com/R167/backblaze).

Backblaze B2 Cloud Storage is similar to Amazon's AWS S3 Storage, but it has a few selling points:

1. They run their own hardware (that's open-sourced, including the schematics, and drive reports)
2. It's $0.005/GB/month vs S3's $0.030/GB/month
3. You actually get a free GB of bandwidth a day, so it might be nice for personal projects.

## Usage

After fetching the repo and running bundle, run `bin/console` and do this:

```
# log in
> Backblaze::B2.login(account_id: "your_backblaze_account_id", application_key: "your_application_key")
# list buckets
> Backblaze::B2::Bucket.buckets
```

## Applications

This is used as a storage backend for Paperclip attachments in Rails. See [paperclip-backblaze](https://github.com/alextsui05/paperclip-backblaze)

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/alextsui05/backblaze. This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere to
the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Version Log

### 0.4.0

Officially hijacking the gem from R167 and bumping the version.
