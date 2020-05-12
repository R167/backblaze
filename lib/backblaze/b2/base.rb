# frozen_string_literal: true

module Backblaze::B2
  ##
  # Base class with helpers for B2 classes
  # @abstract
  class Base
    class << self
      ##
      # Helper method for symbolizing a key from "camelCase" to :snake_case
      #
      # Heavily based on the `underscore` method from ActiveSupport
      # @see https://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-underscore
      def symbolize_key(key)
        word = key.dup
        word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
        word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
        word.tr!("-", "_")
        word.downcase!
        word.to_sym
      end
    end

  end
end
