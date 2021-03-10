module Malba

  # This module represents how a resource should be serialized.
  module Serializer
    # @!parse include InstanceMethods
    # @!parse extend ClassMethods

    # @private
    def self.included(base)
      super
      base.instance_variable_set('@_opts', {}) unless base.instance_variable_defined?('@_opts')
      base.instance_variable_set('@_metadata', {}) unless base.instance_variable_defined?('@_metadata')
      base.include InstanceMethods
      base.extend ClassMethods
    end

    # Instance methods
    module InstanceMethods
      # @param resource [Malba::Resource]
      def initialize(resource)
        @resource = resource
        @hash = resource.serializable_hash
        @hash = {key.to_sym => @hash} if key
        return if metadata.empty?

        # @hash is either Hash or Array
        @hash.is_a?(Hash) ? @hash.merge!(metadata.to_h) : @hash << metadata
      end

      # Use real encoder to actually serialize to JSON
      #
      # @return [String] JSON string
      def serialize
        JSON.dump(@hash)
      end

      private

      def key
        opts = self.class._opts
        opts[:key] == true ? @resource.key : opts[:key]
      end

      def metadata
        metadata = self.class._metadata
        metadata.transform_values { |block| block.call(@resource.object) }
      end
    end

    # Class methods
    module ClassMethods
      attr_reader :_opts, :_metadata

      # @private
      def inherited(subclass)
        super
        %w[_opts _metadata].each { |name| subclass.instance_variable_set("@#{name}", send(name).clone) }
      end

      # Set options, currently key only
      #
      # @param key [Boolean, Symbol]
      def set(key: false)
        @_opts[:key] = key
      end

      # Set metadata
      #
      # @param name [String, Symbol] key for the metadata
      # @param block [Block] the content of the metadata
      def metadata(name, &block)
        @_metadata[name.to_sym] = block
      end
    end
  end

  # This module represents what should be serialized
  module Resource
    # @!parse include InstanceMethods
    # @!parse extend ClassMethods
    DSLS = {_attributes: {}, _serializer: nil, _key: nil, _transform_keys: nil}.freeze

    # @private
    def self.included(base)
      super
      base.class_eval do
        # Initialize
        DSLS.each do |name, initial|
          instance_variable_set("@#{name}", initial.dup) unless instance_variable_defined?("@#{name}")
        end
      end
      base.include InstanceMethods
      base.extend ClassMethods
    end

    # Instance methods
    module InstanceMethods
      attr_reader :object, :_key, :params

      # @param object [Object] the object to be serialized
      # @param params [Hash] user-given Hash for arbitrary data
      def initialize(object, params: {})
        @object = object
        @params = params.freeze
        DSLS.each_key { |name| instance_variable_set("@#{name}", self.class.send(name)) }
      end

      # Get serializer with `with` argument and serialize self with it
      #
      # @param with [nil, Proc, Malba::Serializer] selializer
      # @return [String] serialized JSON string
      def serialize(with: nil)
        serializer = case with
                     when nil
                       @_serializer || empty_serializer
                     when ->(obj) { obj.is_a?(Class) && obj <= Malba::Serializer }
                       with
                     when Proc
                       inline_extended_serializer(with)
                     else
                       raise ArgumentError, 'Unexpected type for with, possible types are Class or Proc'
                     end
        serializer.new(self).serialize
      end

      # A Hash for serialization
      #
      # @return [Hash]
      def serializable_hash
        collection? ? @object.map(&converter) : converter.call(@object)
      end
      alias to_hash serializable_hash

      # @return [Symbol]
      def key
        @_key || self.class.name.delete_suffix('Resource').downcase.gsub(/:{2}/, '_').to_sym
      end

      private

      # rubocop:disable Style/MethodCalledOnDoEndBlock
      def converter
        lambda do |resource|
          @_attributes.transform_values do |attribute|
            fetch_attribute(resource, attribute)
          end
        end
      end
      # rubocop:enable Style/MethodCalledOnDoEndBlock

      def fetch_attribute(resource, attribute)
        case attribute
        when Symbol
          resource.send attribute
        when Proc
          instance_exec(resource, &attribute)
        when Malba::One, Malba::Many
          attribute.to_hash(resource, params: params)
        else
          raise ::Malba::Error, "Unsupported type of attribute: #{attribute.class}"
        end
      end

      def empty_serializer
        klass = Class.new
        klass.include Malba::Serializer
        klass
      end

      def inline_extended_serializer(with)
        klass = empty_serializer
        klass.class_eval(&with)
        klass
      end

      def collection?
        @object.is_a?(Enumerable)
      end
    end

    # Class methods
    module ClassMethods
      attr_reader(*DSLS.keys)

      # @private
      def inherited(subclass)
        super
        DSLS.each_key { |name| subclass.instance_variable_set("@#{name}", instance_variable_get("@#{name}").clone) }
      end

      # Set multiple attributes at once
      #
      # @param attrs [Array<String, Symbol>]
      def attributes(*attrs)
        attrs.each { |attr_name| @_attributes[attr_name.to_sym] = attr_name.to_sym }
      end

      # Set an attribute with the given block
      #
      # @param name [String, Symbol] key name
      # @param block [Block] the block called during serialization
      # @raise [ArgumentError] if block is absent
      def attribute(name, &block)
        raise ArgumentError, 'No block given in attribute method' unless block

        @_attributes[name.to_sym] = block
      end

      # Set One association
      #
      # @param name [String, Symbol]
      # @param condition [Proc]
      # @param resource [Class<Malba::Resource>]
      # @param key [String, Symbol] used as key when given
      # @param block [Block]
      # @see Malba::One#initialize
      def one(name, condition = nil, resource: nil, key: nil, &block)
        @_attributes[key&.to_sym || name.to_sym] = One.new(name: name, condition: condition, resource: resource, &block)
      end
      alias has_one one

      # Set Many association
      #
      # @param name [String, Symbol]
      # @param condition [Proc]
      # @param resource [Class<Malba::Resource>]
      # @param key [String, Symbol] used as key when given
      # @param block [Block]
      # @see Malba::Many#initialize
      def many(name, condition = nil, resource: nil, key: nil, &block)
        @_attributes[key&.to_sym || name.to_sym] = Many.new(name: name, condition: condition, resource: resource, &block)
      end
      alias has_many many

      # Set serializer for the resource
      #
      # @param name [Malba::Serializer]
      def serializer(name)
        @_serializer = name <= Malba::Serializer ? name : nil
      end

      # Set key
      #
      # @param key [String, Symbol]
      def key(key)
        @_key = key.to_sym
      end

      # Delete attributes
      # Use this DSL in child class to ignore certain attributes
      #
      # @param attributes [Array<String, Symbol>]
      def ignoring(*attributes)
        attributes.each do |attr_name|
          @_attributes.delete(attr_name.to_sym)
        end
      end

      # Transform keys as specified type
      #
      # @params type [String, Symbol]
      def transform_keys(type)
        @_transform_keys = type.to_sym
      end
    end
  end

  class << self
    def serialize(object, with: nil, &block)
      raise ArgumentError, 'Block required' unless block

      resource_class.class_eval(&block)
      resource = resource_class.new(object)
      with ||= @default_serializer
      resource.serialize(with: with)
    end

    private

    def resource_class
      @resource_class ||= begin
                            klass = Class.new
                            klass.include(Malba::Resource)
                          end
    end
  end
end
