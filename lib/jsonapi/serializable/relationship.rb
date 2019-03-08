require 'jsonapi/serializable/link'
require 'jsonapi/serializable/relationship/dsl'

module JSONAPI
  module Serializable
    class Relationship
      include DSL

      def initialize(exposures = {}, options = {}, &block)
        exposures.each { |k, v| instance_variable_set("@#{k}", v) }
        @_exposures = exposures
        @_options   = options
        @_links     = {}
        instance_eval(&block)
      end

      def as_jsonapi(included)
        {}.tap do |hash|
          hash[:links] = @_links           if @_links.any?
          hash[:data]  = linkage_data      if included || @_include_linkage
          hash[:meta]  = @_meta            unless @_meta.nil?
          hash[:meta]  = { included: false } if hash.empty?
        end
      end

      # @api private
      def related_resources
        @_related_resources ||= Array(resources)
      end

      private

      # @api private
      def resources
        @_resources ||= @_resources_block.call
      end

      # @api private
      def linkage_data
        return @_linkage_block.call if @_linkage_block

        linkage_data = related_resources.map do |res|
          { type: res.jsonapi_type, id: res.jsonapi_id }
        end

        resources.respond_to?(:each) ? linkage_data : linkage_data.first
      end

      def respond_to_missing?(m, include_private = false)
        @_options[:_resource].respond_to?(m) || super
      end

      def method_missing(m, *args, &block)
        if @_options[:_resource].respond_to?(m, true)
          @_options[:_resource].send(m, *args, &block)
        else
          super
        end
      end
    end
  end
end
