require 'jsonapi/renderer'

module JSONAPI
  module Serializable
    class Renderer
      def initialize(renderer = JSONAPI::Renderer.new)
        @renderer = renderer
      end

      # Serialize resources into a JSON API document.
      #
      # @param resources [nil,Object,Array]
      # @param options [Hash] @see JSONAPI.render
      # @option class [Hash{Symbol=>Class}] A map specifying for each type
      #   the corresponding serializable resource class.
      # @option expose [Hash] The exposures made available in serializable
      #   resource class instances as instance variables.
      # @return [Hash]
      #
      # @example
      #   renderer.render(nil)
      #   # => { data: nil }
      #
      # @example
      #   renderer.render(user, class: { User: SerializableUser })
      #   # => {
      #          data: {
      #            type: 'users',
      #            id: 'foo',
      #            attributes: { ... },
      #            relationships: { ... }
      #          }
      #        }
      #
      # @example
      #   renderer.render([user1, user2], class: { User: SerializableUser })
      #   # => { data: [{ type: 'users', id: 'foo', ... }, ...] }
      def render(resources, options = {})
        options   = options.dup
        klass     = options.delete(:class) || {}
        exposures = options.delete(:expose) || {}
        exposures = exposures.merge(_class: klass)

        resources = build_resources(resources, exposures, klass)

        @renderer.render(options.merge(data: resources))
      end

      # Serialize errors into a JSON API document.
      #
      # @param errors [Array]
      # @param options [Hash] @see JSONAPI.render
      # @option class [Hash{Symbol=>Class}] A map specifying for each type
      #   the corresponding serializable error class.
      # @option expose [Hash] The exposures made available in serializable
      #   error class instances as instance variables.
      # @return [Hash]
      #
      # @example
      #   error = JSONAPI::Serializable::Error.create(id: 'foo', title: 'bar')
      #   renderer.render([error])
      #   # => { errors: [{ id: 'foo', title: 'bar' }] }
      def render_errors(errors, options = {})
        options   = options.dup
        klass     = options.delete(:class) || {}
        exposures = options.delete(:expose) || {}

        errors = errors.map { |e| _build(e, exposures, klass) }

        @renderer.render(options.merge(errors: errors))
      end

      private

      # @api private
      def build_resources(resources, exposures, klass)
        if resources.nil?
          nil
        elsif resources.respond_to?(:to_ary)
          Array(resources).map { |obj| _build(obj, exposures, klass) }
        else
          _build(resources, exposures, klass)
        end
      end

      # @api private
      def _build(object, exposures, klass)
        klass[object.class.name.to_sym].new(object, exposures)
      end
    end
  end
end
