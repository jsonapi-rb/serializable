module JSONAPI
  module Serializable
    class Resource
      # Extension for handling conditional fields in serializable resources.
      #
      # @usage
      #   class SerializableUser < JSONAPI::Serializable::Resource
      #     extend JSONAPI::Serializable::Resource::ConditionalFields
      #
      #     attribute :email, if: -> { @current_user.admin? }
      #     has_many :friends, unless: -> { @object.private_profile? }
      #   end
      #
      module ConditionalFields
        def self.prepended(klass)
          warn <<-EOT
  DERPRECATION WARNING (called from #{caller_locations(1...2).first}):
  Prepending `#{name}' is deprecated and will be removed in future releases. Use `Object#extend' instead.
  EOT

          klass.extend self
        end

        def self.extended(klass)
          klass.module_eval do
            prepend InstanceMethods

            class << self
              attr_accessor :field_condition_blocks
              attr_accessor :link_condition_blocks
            end
            self.field_condition_blocks ||= {}
            self.link_condition_blocks  ||= {}

          end
        end

        def inherited(klass)
          super
          klass.field_condition_blocks = field_condition_blocks.dup
          klass.link_condition_blocks  = link_condition_blocks.dup
        end

        # Handle the `if` and `unless` options for attributes.
        #
        # @example
        #   attribute :email, if: -> { @current_user.admin? }
        #
        def attribute(name, options = {}, &block)
          super
          _register_condition(field_condition_blocks, name, options)
        end



        # Handle the `if` and `unless` options for relationships (has_one,
        #   belongs_to, has_many).
        #
        # @example
        #   has_many :friends, unless: -> { @object.private_profile? }
        #
        def relationship(name, options = {}, &block)
          super
          _register_condition(field_condition_blocks, name, options)
        end

        # Handle the `if` and `unless` options for links.
        #
        # @example
        #
        #   link :self, if: -> { @object.render_self_link? } do
        #     "..."
        #   end
        def link(name, options = {}, &block)
          super(name, &block)
          _register_condition(link_condition_blocks, name, options)
        end

        # NOTE(beauby): Re-aliasing those is necessary for the
        #   overridden `#relationship` method to be called.
        alias has_many   relationship
        alias has_one    relationship
        alias belongs_to relationship

        # @api private
        def _register_condition(condition_blocks, name, options)
          condition_blocks[name.to_sym] =
            if options.key?(:if)
              options[:if]
            elsif options.key?(:unless)
              proc { !instance_exec(&options[:unless]) }
            end
        end
      end

      module InstanceMethods
        # @api private
        def requested_attributes(fields)
          super.select do |k, _|
            _conditionally_included?(self.class.field_condition_blocks, k)
          end
        end

        # @api private
        def requested_relationships(fields)
          super.select do |k, _|
            _conditionally_included?(self.class.field_condition_blocks, k)
          end
        end

        # @api private
        def link_blocks
          super.select do |k, _|
            _conditionally_included?(self.class.link_condition_blocks, k)
          end
        end

        # @api private
        def _conditionally_included?(condition_blocks, field)
          condition = condition_blocks[field]
          condition.nil? || instance_exec(&condition)
        end
      end
    end
  end
end
