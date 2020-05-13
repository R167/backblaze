# frozen_string_literal: true

module Backblaze::B2
  module Resource
    # @!parse
    #   extend ClassMethods

    def self.included(klass)
      klass.extend(ClassMethods)
      klass.private_class_method :new
    end

    module ClassMethods
      def self.extended(klass)
        # klass.attr_accessor :account
      end

      def from_api(account, attributes)
        new(account, attrs: attributes)
      end

      protected

      def attributes_to_symbols(attrs)
        Hash[attrs.map { |attr| [attr.freeze, symbolize_key(attr)] }]
      end

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

        self.attr_reader(*sym_to_str.keys)

        self.const_set(:ATTR_STR_TO_SYM, str_to_sym.freeze)
        self.const_set(:ATTR_SYM_TO_STR, sym_to_str.freeze)
        self.const_set(:ATTR_SETTER_LOOKUP, setter_lookup.freeze)
      end
    end

    ##
    # Take a hash of options returned from B2 api and automatically set those attributes
    def initialize(account = nil, attrs: {})
      @account = account
      set_attributes!(attrs)
    end

    def to_h(json = false)
      self.class::ATTR_SETTER_LOOKUP.select{|k, v| k.is_a?(json ? String : Symbol)}.map{|k,v| [k, self.instance_variable_get(v)]}.to_h
    end

    def to_json
      to_h(json = true).to_json
    end

    # @return [Account]
    attr_accessor :account

    def account
      @account or raise ValidationError, "Attribute never set: account="
    end

    ##
    # Convert from the long format used by java and B2 to a ruby {Time}
    def long_to_time(long)
      return timestamp unless long.is_a?(Integer)
      Time.at(0, long, :millisecond)
    end

    ##
    # Convert from a ruby {Time} to the long format used by java
    def time_to_long(time)
      return time unless time.is_a?(Time)
      time.to_i * 1000 + time.usec / 1000
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
