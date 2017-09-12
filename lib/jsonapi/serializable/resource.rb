require 'jsonapi/serializable/resource/dsl'

require 'jsonapi/serializable/link'
require 'jsonapi/serializable/relationship'

require 'jsonapi/serializable/resource/conditional_fields'
require 'jsonapi/serializable/resource/key_format'

module JSONAPI
  module Serializable
    class Resource
      extend DSL

      # Default the value of id.
      id { @object.public_send(:id).to_s }

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def initialize(object, exposures = {})
        @object = object
        @_exposures = exposures
        @_exposures.each { |k, v| instance_variable_set("@#{k}", v) }

        @_id = instance_eval(&self.class.id_block).to_s
        @_type = if (b = self.class.type_block)
                   instance_eval(&b).to_sym
                 else
                   self.class.type_val || :unknown
                 end
        @_relationships = self.class.relationship_blocks
                              .each_with_object({}) do |(k, v), h|
          opts = self.class.relationship_options[k] || {}
          h[k] = Relationship.new(@object, @_exposures, opts, &v)
        end
        @_meta = if (b = self.class.meta_block)
                   instance_eval(&b)
                 else
                   self.class.meta_val
                 end

        freeze
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def as_jsonapi(fields: nil, include: [])
        attrs = requested_attributes(fields).each_with_object({}) do |(k, v), h|
          h[k] = instance_eval(&v)
        end
        rels = requested_relationships(fields)
               .each_with_object({}) do |(k, v), h|
          h[k] = v.as_jsonapi(include.include?(k))
        end
        links = link_blocks.each_with_object({}) do |(k, v), h|
          h[k] = Link.as_jsonapi(@_exposures, &v)
        end
        {}.tap do |hash|
          hash[:id]   = @_id
          hash[:type] = @_type
          hash[:attributes]    = attrs if attrs.any?
          hash[:relationships] = rels  if rels.any?
          hash[:links] = links if links.any?
          hash[:meta]  = @_meta  unless @_meta.nil?
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def jsonapi_type
        @_type
      end

      def jsonapi_id
        @_id
      end

      def jsonapi_related(include)
        @_relationships
          .select { |k, _| include.include?(k) }
          .each_with_object({}) { |(k, v), h| h[k] = v.related_resources }
      end

      def jsonapi_cache_key(options)
        "#{jsonapi_type} - #{jsonapi_id}" \
        "- #{options[:include].to_a.sort}" \
        "- #{(options[:fields] || Set.new).to_a.sort}"
      end

      private

      # @api private
      def requested_attributes(fields)
        self.class.attribute_blocks
            .select { |k, _| fields.nil? || fields.include?(k) }
      end

      # @api private
      def requested_relationships(fields)
        @_relationships.select { |k, _| fields.nil? || fields.include?(k) }
      end

      # @api private
      def link_blocks
        self.class.link_blocks
      end
    end
  end
end
