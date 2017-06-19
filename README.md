# paperclip-backblaze

The `paperclip-backblaze` provides a [Paperclip](https://github.com/thoughtbot/paperclip) storage adapter so that
attachments can be saved to [Backblaze B2 Cloud Storage API](https://www.backblaze.com/b2/docs/).
It makes use of Winston Durand's [backblaze](https://github.com/R167/backblaze) gem
to access the B2 API behind the scenes.

Backblaze B2 Cloud Storage is similar to Amazon's AWS S3 Storage, but it has a few selling points:

1. They run their own hardware (that's open-sourced, including the schematics, and drive reports)
2. It's $0.005/GB/month vs S3's $0.030/GB/month
3. You actually get a free GB of bandwidth a day, so it might be nice for personal projects.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'paperclip-backblaze', github: 'alextsui05/paperclip-backblaze'
```
And then execute:

    $ bundle

## Usage

You should be familiar with configuring Paperclip attachments for your model.
If not, please start with the Paperclip documentation
[here](https://github.com/thoughtbot/paperclip#usage).

Configuring Backblaze storage is very similar to [configuring S3 storage](http://www.rubydoc.info/gems/paperclip/Paperclip/Storage/S3).
Let's suppose we have a `Note` model with an `image` attachment that we would
like to be backed by Backblaze storage. In the model, it might be configured
like this:

```.rb
# app/models/note.rb
class Note < ApplicationRecord
  has_attached_file :image,
    storage: :backblaze,
    b2_credentials: Rails.root.join('config/b2.yml'),
    b2_bucket: 'bucket_for_my_app'
  ...
```

```.yml
# config/b2.yml
account_id: 123456789abc
application_key: 0123456789abcdef0123456789abcdef0123456789
```

Currently, these are required options:

- `:storage` - This should be set to :backblaze in order to use this
   storage adapter.

- `:b2_credentials` - This should point to a YAML file containing your B2
   account ID and application key. The contents should look something
   like `b2.yml` above.

- `:b2_bucket` - This should name the bucket to save files to.

## Contributing

This started as a proof of concept for a hobby project, so there's lots of room
for improvement, and it would be great to have your help.

Bug reports and pull requests are welcome on GitHub at
https://github.com/alextsui05/paperclip-backblaze. This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere to
the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
