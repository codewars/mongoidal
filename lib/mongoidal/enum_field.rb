module Mongoidal
  module EnumField
    extend ActiveSupport::Concern

    module ClassMethods
      protected

      def enum_field(field_name, options = {})
        raise "values option is required" unless options.has_key? :values

        options[:type] ||= Symbol

        field_options = options.slice(:type, :default, :index, :required)

        field field_name, field_options

        values = options[:values]
        actual_values = values.dup

        # mongoid 3.1.0 now validates against the pre-serialized value meaning that
        # if a string is ever used to set a value then it's symbol version will not be tested against.
        # To fix this we make sure both symbol and string representations are supported.
        inclusion_values = actual_values.clone
        actual_values.each do |v|
          inclusion_values << v.to_s if v.is_a?(Symbol)
        end

        validates_inclusion_of field_name,
                               in: inclusion_values,
                               message: options.has_key?(:message) ? options[:message] : 'invalid value',
                               allow_nil: options[:allow_nil]

        ## helper methods:

        define_singleton_method "#{field_name}_values" do
          values
        end

        # define the is_? shortcut methods
        unless options[:omit_shortcuts]
          suffix = options[:suffix] == false ? '' : options[:suffix] || "_#{field_name}"
          prefix = options[:prefix] == false ? '' : options[:prefix] || 'is_'
          values.each do |key|
            unless key.blank?
              define_method "#{prefix}#{key}#{suffix}?" do
                val = self.__send__ field_name
                val == key
              end
            end
          end
        end

        unless actual_values.include? ''
          # treat empty values as nil values
          before_validation do |doc|
            if doc.__send__(field_name).blank?
              doc.__send__("#{field_name}=", nil)
            end
          end
        end

        if respond_to?(:translate)
          # allows easy access to translations
          define_method "#{field_name}_translate" do |val = nil|
            val ||= self.__send__ field_name
            self.class.__send__ "#{field_name}_value_translate", val
          end

          #alias translate method to short form
          define_method "#{field_name}_t" do |val = nil|
            self.__send__ "#{field_name}_translate", val
          end

          define_singleton_method "#{field_name}_value_translate" do |val|
            self.translate("#{field_name}.#{val}")
          end

          define_singleton_method "#{field_name}_value_t" do |val|
            self.translate("#{field_name}.#{val}")
          end
        end
      end
    end
  end
end