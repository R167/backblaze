# frozen_string_literal: true

module Backblaze::B2
  module Resource
    # @!parse
    #   extend ClassMethods

    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def self.extended(klass)
        # klass.attr_accessor :account
      end

      def from_api(account, attributes)
        new(account, attrs: attributes)
      end

      protected

      ##
      # Create these attributes on the class
      def create_attributes(attrs)
        str_to_sym = attributes_to_symbols(attrs)
        sym_to_str = str_to_sym.invert

        setter_lookup = {}
        str_to_sym.each do |k, v|
          setter_lookup[k] = :"@#{v}"
          setter_lookup[v] = :"@#{v}"
        end

        attr_reader(*sym_to_str.keys)

        const_set(:ATTR_STR_TO_SYM, str_to_sym.freeze)
        const_set(:ATTR_SYM_TO_STR, sym_to_str.freeze)
        const_set(:ATTR_SETTER_LOOKUP, setter_lookup.freeze)
      end
    end

    ##
    # Take a hash of options returned from B2 api and automatically set those attributes
    def initialize(account = nil, attrs: {})
      @account = account
      set_attributes!(attrs)
    end

    def to_h(json = false)
      self.class::ATTR_SETTER_LOOKUP.select { |k, v| k.is_a?(json ? String : Symbol) }.map { |k, v| [k, instance_variable_get(v)] }.to_h
    end

    def to_json
      to_h(true).to_json
    end

    # @param [Account]
    attr_writer :account

    def account
      @account || raise(ValidationError, "Attribute never set: account=")
    end

    private

    def set_attributes!(attrs)
      lookup = self.class::ATTR_SETTER_LOOKUP
      attrs.each do |k, v|
        if lookup.include?(k)
          instance_variable_set(lookup[k], v)
        end
      end
    end
  end
end
