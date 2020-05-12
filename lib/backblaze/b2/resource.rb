# frozen_string_literal: true

module Backblaze::B2
  module Resource
    # @!parse
    #   extend ClassMethods

    def self.included(klass)
      klass.extend(ClassMethods)
      # klass.private_class_method :new
    end

    module ClassMethods
      def self.extended(klass)
        klass.attr_accessor :api
      end

      def from_api(api, attributes)
        new(api, attributes)
      end

      private

      def attributes_to_symbols(attrs)
        Hash[attrs.map { |attr| [attr.freeze, symbolize_key(attr)] }]
      end

      def create_attributes(attrs)
        str_to_sym = attributes_to_symbols(attrs)
        str_to_setter = str_to_sym.map{|k, v| [k, :"@#{v}"]}.to_h
        sym_to_str = str_to_sym.invert

        self.attr_reader(*sym_to_str.keys)

        self.const_set(:ATTR_STR_TO_SYM, str_to_sym.freeze)
        self.const_set(:ATTR_STR_TO_SETTER, str_to_setter.freeze)
        self.const_set(:ATTR_SYM_TO_STR, str_to_sym.freeze)

        # self.private_constant(:ATTR_STR_TO_SETTER)
      end
    end

    ##
    # Take a hash of options returned from B2 api and automatically set those attributes
    def initialize(api=nil, options={})
      @api = api
      set_attributes!(options)
    end

    def api=(api)
      @api = api
    end

    private

    def api
      @api or raise ValidationError, "Attribute never set, api"
    end

    def set_attributes!(attrs)
      attrs.each do |k, v|
        if self.class::ATTR_STR_TO_SETTER.include?(k)
          instance_variable_set(self.class::ATTR_STR_TO_SETTER[k], v)
        end
      end
    end
  end
end
