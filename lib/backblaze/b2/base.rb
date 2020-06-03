# frozen_string_literal: true

module Backblaze::B2
  ##
  # Base class with helpers for B2 classes
  # @abstract
  class Base
    include Utils

    # @return [Account] account object is tied to
    attr_reader :account

    def initialize(account, properties = {})
      @account = account
      set_properties(properties)
    end

    # @abstract
    def refresh!
      raise NotImplementedError, "Subclasses must implement this"
    end

    # Load fresh data from B2. Calls {#refresh!}
    #
    # This can't be an alias because otherwise subclasses won't get it.
    # (see #refresh!)
    def load!
      refresh!
    end

    def [](attr, fetch: nil)
      return nil unless has_attribute?(attr)

      should_fetch = fetch.nil? ? fetch? : fetch
      fetched = false
      begin
        @properties.fetch(attr_key(attr))
      rescue KeyError
        if should_fetch && !fetched
          refresh!
          fetched = true
          retry
        else
          raise
        end
      end
    end

    def []=(attr, value)
      @properties[attr_key(attr)] = value
    end

    def has_attribute?(attr)
      valid_attributes.include?(attr_key(attr))
    end

    # @abstract
    # @return [Set]
    def valid_attributes
      raise NotImplementedError, "Must be implemented by subclasses"
    end

    private

    # Default case for "should I fetch from the server?"
    def fetch?
      account.fetch?
    end

    # All internal properties are represented as b2 camelcase attributes
    def set_properties(properties)
      properties.transform_keys! { |key| attr_key(key) }
      @properties = properties
    end

    def attr_key(attr)
      attr.is_a?(Symbol) ? camelize_key(attr) : attr
    end
  end
end
