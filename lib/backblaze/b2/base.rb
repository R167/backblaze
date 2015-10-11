module Backblaze::B2
  class Base
    include HTTParty

    # @!method get(path, options={}, &block)
    # Calls the class level equivalent from HTTParty
    # @see http://www.rubydoc.info/github/jnunemaker/httparty/HTTParty/ClassMethods HTTParty::ClassMethods

    # @!method head(path, options={}, &block)
    # (see #get)

    # @!method post(path, options={}, &block)
    # (see #get)

    # @!method put(path, options={}, &block)
    # (see #get)

    [:get, :head, :post, :put].each do |req|
      define_method(req) do |path, options={}, &block|
        self.class.send(req, path, options, &block)
      end
    end
  end
end
